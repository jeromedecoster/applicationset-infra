#!/bin/bash

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

log START $(date "+%Y-%d-%m %H:%M:%S")
START=$SECONDS

[[ -z $(printenv | grep ^CHDIR=) ]] \
    && { error ABORT CHDIR env variable is required; exit 1; } \
    || log CHDIR $CHDIR

# /!\ very very useful for saving THOUSANDS of megabytes on your computer /!\
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

# https://www.terraform.io/cli/commands/init
# Error: Inconsistent dependency lock file
# use `init -upgrade` to update the locked dependency selections

# https://www.terraform.io/cli/commands/init#child-module-installation
# use `-get=false` to skip child module installation
# /!\ 1. if you use `-upgrade` without `-get=false`, every `terraform init` call
# will force download all the modules /!\
# /!\ 2. but if you use `-upgrade -get=false`, the first call will fail to download
# the modules /!\
# The first install (directory .terraform still not exists) option `-get` is ignored
# then become `-get=false` the next times
[[ ! -d "$CHDIR/.terraform" ]] && GET= || GET='-get=false'
terraform -chdir="$CHDIR" init -upgrade $GET

log END $(date "+%Y-%d-%m %H:%M:%S")
info DURATION $(($SECONDS - $START)) seconds