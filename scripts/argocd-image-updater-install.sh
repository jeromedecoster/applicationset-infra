#!/bin/bash

# usage:
# CHECK_INTERVAL=<delay> argocd-image-updater-install.sh
#
# delay:
#   3m | 2m10s | 1m | 30s 

# https://github.com/argoproj-labs/argocd-image-updater/blob/master/docs/install/reference.md#flags
# --interval <duration>
# default argocd-image-updater value : 2m0s

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

info SCRIPT $0

[[ -z $(printenv | grep ^CHECK_INTERVAL=) ]] \
    && { error ABORT CHECK_INTERVAL env variable is required; exit 1; } \
    || log CHECK_INTERVAL $CHECK_INTERVAL

log START $(date "+%Y-%d-%m %H:%M:%S")
START=$SECONDS

# check is the service account argocd-image-updater exists
updater-sa() {
    kubectl get sa argocd-image-updater -n argocd 2>/dev/null 
}

if [[ -z $(updater-sa) ]]; then
    # quick delete
    # kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

    # direct install
    # kubectl apply \
    #     --namespace argocd \
    #     --filename https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

    # patched install : argocd-image-updater command using --interval 1m
    # check image registry every 1 minute instead of every 2 minutes by default
    # https://argocd-image-updater.readthedocs.io/en/stable/install/reference/#flags
    # /!\ fastest interval is possible : you can set, for example, '30s' instead of '1m'
    #     it works, but argocd-image-updater starts with this warning message :
    #     Check interval is very low - it is not recommended to run below 1m0s
    TEMP_DIR=$(mktemp --directory /tmp/argocd-im-up-XXXX)
    info TEMP_DIR $TEMP_DIR
    curl https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml \
        --output $TEMP_DIR/install.yaml \
        --silent

    cat >$TEMP_DIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- install.yaml

patches:
- target:
    kind: Deployment
    name: argocd-image-updater
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/args
      value: ['--interval', '$CHECK_INTERVAL']
EOF

    log KUSTOMIZE $TEMP_DIR/kustomization.yaml
    cat $TEMP_DIR/kustomization.yaml

    kustomize build $TEMP_DIR \
    | kubectl apply \
        --namespace argocd \
        --filename -   
fi
    
log END $(date "+%Y-%d-%m %H:%M:%S")
info DURATION $(($SECONDS - $START)) seconds