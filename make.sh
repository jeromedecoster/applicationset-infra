#!/bin/bash

log() { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }          # $1 background white
info() { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }       # $1 background green
warn() { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; }  # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

# the directory containing the script file
export PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"

#
# variables
#
[[ -f $PROJECT_DIR/.env ]] \
    && source $PROJECT_DIR/.env \
    || warn WARN .env file is missing

#
# overwrite TF variables
#
export TF_VAR_project_name=$PROJECT_NAME
export TF_VAR_module_name=$MODULE_NAME
export TF_VAR_aws_region=$AWS_REGION
export TF_VAR_github_owner=$GITHUB_OWNER
export TF_VAR_github_repo_infra=$GITHUB_REPO_INFRA
export TF_VAR_github_repo_storage=$GITHUB_REPO_STORAGE
export TF_VAR_github_repo_convert=$GITHUB_REPO_CONVERT
export TF_VAR_github_repo_website=$GITHUB_REPO_WEBSITE
export TF_VAR_ecr_repo=$APP_NAME

# /!\ create a token here : https://github.com/settings/tokens
# /!\ must be checked : repo + admin:public_key

# https://unix.stackexchange.com/a/421111
# instead of source .env 2>/dev/null (get all variables from .env)
# define only GITHUB_TOKEN from .env
# eval "$(cat .env 2>/dev/null | grep ^GITHUB_TOKEN=)"
log GITHUB_TOKEN $GITHUB_TOKEN
export TF_VAR_github_token=$GITHUB_TOKEN

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

env-create() {
    # setup .env file with default values
    scripts/env-file.sh .env \
        AWS_PROFILE=default \
        PROJECT_NAME=applicationset \
        MODULE_NAME=applicationset-infra

    # setup .env file again
    # /!\ use your own values /!\
    scripts/env-file.sh .env \
        AWS_REGION=eu-west-3 \
        GITHUB_OWNER=jeromedecoster \
        GITHUB_REPO_INFRA=git@github.com:jeromedecoster/applicationset-infra.git \
        GITHUB_REPO_STORAGE=git@github.com:jeromedecoster/applicationset-storage.git \
        GITHUB_REPO_CONVERT=git@github.com:jeromedecoster/applicationset-convert.git \
        GITHUB_REPO_WEBSITE=git@github.com:jeromedecoster/applicationset-website.git \
        GITHUB_TOKEN=
}

terraform-init() {
    export CHDIR="$PROJECT_DIR/terraform"
    scripts/terraform-init.sh
    scripts/terraform-validate.sh
}

terraform-create() {
    if [[ -z $(echo $GITHUB_TOKEN) ]]; then
        error ABORT GITHUB_TOKEN is not defined in .env file
        exit 0
    fi

    export CHDIR="$PROJECT_DIR/terraform"
    scripts/terraform-validate.sh
    scripts/terraform-apply.sh
}

argocd-open() {
    log KIND_LISTEN_ADDRESS $KIND_LISTEN_ADDRESS
    log KIND_LOCALHOST_PORT $KIND_LOCALHOST_PORT

    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
        --namespace argocd \
        --output jsonpath="{.data.password}" |
        base64 --decode)
    log ARGOCD_PASSWORD $ARGOCD_PASSWORD
    scripts/env-file.sh .env ARGOCD_PASSWORD=$ARGOCD_PASSWORD

    # xdg-open https://0.0.0.0:8443
    info OPEN $KIND_LISTEN_ADDRESS:$KIND_LOCALHOST_PORT
    if [[ -n $(which xdg-open) ]]; then
        xdg-open https://$KIND_LISTEN_ADDRESS:$KIND_LOCALHOST_PORT
    elif [[ -n $(which open) ]]; then
        open https://$KIND_LISTEN_ADDRESS:$KIND_LOCALHOST_PORT
    fi

    warn ACCEPT insecure self-signed certificate
    info LOGIN admin
    info PASSWORD $ARGOCD_PASSWORD
}

argocd-login() {
    log KIND_LISTEN_ADDRESS $KIND_LISTEN_ADDRESS
    log KIND_LOCALHOST_PORT $KIND_LOCALHOST_PORT
    
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
        --namespace argocd \
        --output jsonpath="{.data.password}" |
        base64 --decode)
    log ARGOCD_PASSWORD $ARGOCD_PASSWORD
    scripts/env-file.sh .env ARGOCD_PASSWORD=$ARGOCD_PASSWORD
    
    # must match kind_config.node[role = "control-plane"].extra_port_mappings[container_port = 30080]
    argocd login $KIND_LISTEN_ADDRESS:$KIND_LOCALHOST_PORT \
        --insecure \
        --username=admin \
        --password=$ARGOCD_PASSWORD
}

argocd-finalize-ns() {
    # https://stackoverflow.com/a/53661717/1503073
    TEMP_DIR=$(mktemp --directory /tmp/argocd-XXXX)
    info TEMP_DIR $TEMP_DIR

    kubectl proxy &

    cd  $TEMP_DIR
    # get ns data as JSON, clear .spec.finalizers content, write as JSON file
    kubectl get namespace argocd -o json | jq '.spec = { "finalizers":[] }' > ns.json
    # finalize namespace
    curl -k -H "Content-Type: application/json" -X PUT --data-binary @ns.json 127.0.0.1:8001/api/v1/namespaces/argocd/finalize

    # https://stackoverflow.com/a/61264131/1503073
    # option -f, --full : the pattern is normally only matched against the process name.
    pkill -9 -f "kubectl proxy"
}

image-updater-status() {
    kubectl get deploy \
        --selector  app.kubernetes.io/name=argocd-image-updater \
        --namespace argocd \
        --output json \
        | jq '.items[].status.conditions[] | select(.type == "Available").status' \
        --raw-output
}

image-updater-logs() {
    if [[ $(image-updater-status) != 'True' ]]; then
        log WAIT argocd-image-updater
        kubectl wait deploy argocd-image-updater \
            --timeout=180s \
            --namespace argocd \
            --for=condition=Available=True
    fi

    kubectl logs --selector app.kubernetes.io/name=argocd-image-updater \
        --namespace argocd \
        --follow
}

terraform-destroy() {
    if [[ -z $(echo $GITHUB_TOKEN) ]]; then
        error ABORT GITHUB_TOKEN is not defined in .env file
        exit 0
    fi
    
    # /!\ warn : destroy application + applicationset resources within argocd
    # before delete all resources

    terraform -chdir=$PROJECT_DIR/terraform destroy -auto-approve

    # terraform -chdir=$PROJECT_DIR/terraform state list
}

# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info EXECUTE $1; eval $1; } || usage
exit 0
