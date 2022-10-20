#!/bin/bash

# usage:
# TIMEOUT_RECONCILIATION=<delay> argocd-install.sh
#
# delay:
#   3m | 2m10s | 1m | 30s 

# https://github.com/ishitasequeira/argo-cd/blob/b329e4d91c00d48d1dd2dea3d5002b381603a899/manifests/install.yaml#L10245-L10256
# env var `ARGOCD_RECONCILIATION_TIMEOUT` taken from key `timeout.reconciliation` within ConfigMap `argocd-cm`

# https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.0-2.1/#replacing-app-resync-flag-with-timeoutreconciliation-setting
# default argocd value : timeout.reconciliation: 180s

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

info SCRIPT $0

[[ -z $(printenv | grep ^TIMEOUT_RECONCILIATION=) ]] \
    && { error ABORT TIMEOUT_RECONCILIATION env variable is required; exit 1; } \
    || log TIMEOUT_RECONCILIATION $TIMEOUT_RECONCILIATION

log START $(date "+%Y-%d-%m %H:%M:%S")
START=$SECONDS

# check if the namespace argocd exists
argocd-ns() {
    kubectl get ns argocd 2>/dev/null
}

if [[ -z $(argocd-ns) ]]; then
    log CREATE namespace argocd
    kubectl create ns argocd 2>/dev/null
fi

# check if the service argocd-applicationset-controller is defined
# in the argocd namespace. This is the first thing available when
# argocd is installed
argocd-svc() {
    kubectl get svc argocd-applicationset-controller -n argocd 2>/dev/null
}

if [[ -z $(argocd-svc) ]]; then
    # quick delete
    # kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null && kubectl delete ns argocd 2>/dev/null

    # direct install
    # kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    TEMP_DIR=$(mktemp --directory /tmp/argocd-XXXX)
    info TEMP_DIR $TEMP_DIR

    curl https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
        --output $TEMP_DIR/install.yaml \
        --silent

    cat >$TEMP_DIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- install.yaml

patches:
- target:
    kind: ConfigMap
    name: argocd-cm
  patch: |-
    - op: add
      path: /data
      value:
        timeout.reconciliation: "$TIMEOUT_RECONCILIATION"
EOF

    log KUSTOMIZE $TEMP_DIR/kustomization.yaml
    cat $TEMP_DIR/kustomization.yaml

    kustomize build $TEMP_DIR \
    | kubectl apply \
        --namespace argocd \
        --filename -
fi

# by default : ClusterIP
# if patched : NodePort
argocd-server-lb() {
    kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.type}' 2>/dev/null
}

if [[ $(argocd-server-lb) != 'NodePort' ]]; then
    log WAIT argocd-server
    kubectl wait deploy argocd-server \
        --timeout=180s \
        --namespace argocd \
        --for=condition=Available=True


    # convert ClusterIP to NodePort
    log CREATE nodeport
    kubectl patch svc argocd-server \
        --namespace argocd \
        --patch '{"spec": {"type": "NodePort"}}'

    log PORTS service argocd-server ports
    kubectl get svc argocd-server \
        --namespace argocd \
        --output yaml \
        | yq '.spec.ports'

    # https://mikefarah.gitbook.io/yq/operators/path#get-array-index
    # find the index of https port
    HTTPS_INDEX=$(kubectl get svc argocd-server \
        --namespace argocd \
        --output yaml \
        | yq '.spec.ports[] | select(.name == "https") | path | .[-1]')
    log HTTPS_INDEX $HTTPS_INDEX

    kubectl patch svc argocd-server \
        --patch='[{"op": "replace", "path": "/spec/ports/'$HTTPS_INDEX'/nodePort", "value": 30080}]' \
        --type=json \
        --namespace argocd

    log PORTS service argocd-server ports
    kubectl get svc argocd-server \
        --namespace argocd \
        --output yaml \
        | yq '.spec.ports'
fi

# https://docs.docker.com/engine/reference/commandline/ps/#filtering
# container id filtered by exposed port
DOCKER_ID=$(docker ps --filter expose=30080 --format "{{.ID}}")
log DOCKER_ID $DOCKER_ID

# https://docs.docker.com/engine/reference/commandline/inspect/#find-a-specific-port-mapping
# host ip that expose port 30080
HOST_IP=$(docker inspect $DOCKER_ID --format='{{(index (index .NetworkSettings.Ports "30080/tcp") 0).HostIp}}')
log HOST_IP $HOST_IP

argocd-initial-secret() {
    kubectl get secret argocd-initial-admin-secret -n argocd 2>/dev/null
}

if [[ -z $(argocd-initial-secret) ]]; then
    log WAIT kubectl secret argocd-initial-admin-secret
    while [[ -z $(argocd-initial-secret) ]]; do sleep 1; done
fi

ARGO_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
    --namespace argocd \
    --output jsonpath="{.data.password}" |
    base64 --decode)

info OPEN "https://$HOST_IP:8080"
warn ACCEPT insecure self-signed certificate
info LOGIN admin
info PASSWORD $ARGO_PASSWORD

log LOGIN argocd
argocd login $HOST_IP:8080 \
    --insecure \
    --username=admin \
    --password=$ARGO_PASSWORD

log END $(date "+%Y-%d-%m %H:%M:%S")
info DURATION $(($SECONDS - $START)) seconds