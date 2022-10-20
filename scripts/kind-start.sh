#!/bin/bash

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

info SCRIPT $0 $@

log START $(date "+%Y-%d-%m %H:%M:%S")
START=$SECONDS

if [[ -z $(kind get clusters | grep ^cluster$) ]];
then
    TEMP_DIR=$(mktemp --directory /tmp/kind-XXXX)
    info TEMP_DIR $TEMP_DIR

    # https://medium.com/ibm-cloud/gitops-quick-start-with-kubernetes-kind-cluster-5677f94adf69
    # the range of valid ports is 30000-32767

    # https://kind.sigs.k8s.io/docs/user/quick-start#mapping-ports-to-the-host-machine
    # https://kind.sigs.k8s.io/docs/user/configuration/#extra-port-mappings
    # extraPortMappings : mapping ports to the host machine
    cat >$TEMP_DIR/config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
    - containerPort: 30080
      hostPort: 8443
EOF
#   - containerPort: 30080
#     hostPort: 8080
#   - containerPort: 30000
#     hostPort: 9000

    log CONFIG $TEMP_DIR/config.yaml
    cat $TEMP_DIR/config.yaml

    # delete cluster
    # kind delete cluster --name cluster

    kind create cluster --config $TEMP_DIR/config.yaml --name cluster
fi

# message stdout : empty || context-name
# message stderr : error: current-context is not set
context() {
    kubectl config current-context 2>/dev/null 
}

if [[ -z $(context) ]]; then
    log WAIT kubectl config current-context
    while [[ -z $(context) ]]; do sleep 1; done
fi

# kubernetes shortcuts
# po : Pods
# rs : ReplicaSets
# deploy : Deployments
# svc : Services
# ns : Namespaces
# netpol : Network policies
# pv : Persistent Volumes
# pvc : PersistentVolumeClaims
# sa : Service Accounts

namespaces() {
    kubectl get ns 2>/dev/null
}

if [[ -z $(namespaces) ]]; then
    log WAIT kubectl get namespace
    while [[ -z $(namespaces) ]]; do sleep 1; done
fi

docker ps --filter name=cluster

log END $(date "+%Y-%d-%m %H:%M:%S")
info DURATION $(($SECONDS - $START)) seconds