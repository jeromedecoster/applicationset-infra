#!/bin/bash

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

usage() {
    echo -ne "\033[0;4musage\033[0m "
    echo "$(basename $0) <file> [var] [var] [...]"
    echo
    echo "      option var can be :"
    echo "      - a key/value pair like VARIABLE=VALUE"
    echo "      - a key like VARIABLE (value will be retrived from environment vars)"
    echo
    echo "      env var:"
    echo "      - ENV_FILE_EMPTY_OVERWRITE=1 (allow reset value)"
    echo
    echo "      examples:"
    echo "      - $(basename $0) .env AWS_REGION=us-east-1"
    echo "      - AWS_REGION=eu-west-3 $(basename $0) .env AWS_REGION"
    echo "      - ENV_FILE_EMPTY_OVERWRITE=1 $(basename $0) .env AWS_REGION="
    echo
}


[[ $# -lt 2 ]] && { error abort argument error; usage; exit 1; }

# env-file.sh .env VAR1=abc VAR2 VAR3=ghi VAR4= 

# return the line where `$1` is defined in printenv
find_env() {
    printenv | grep "^$1="
}

# return the line where `$1` is defined in `$CONTENT`
find_cont() {
    echo "$CONTENT" | grep "^$1="
}

# replace the variable in `$CONTENT` by `$1`
# presence must be previously checked with `find_cont`
replace_cont() {
    # get the variable name
    local VARIABLE=$(echo "$1" | cut -f 1 -d =)
    # log VARIABLE $VARIABLE

    # get the value
    local VALUE=$(echo "$1" | cut -f 2 -d =)
    # log VALUE $VALUE

    # $VALUE is not empty
    if [[ -n "$VALUE" ]]; then
        # the same line $1 is not found (update value)
        if [[ -z $(echo "$CONTENT" | grep ^$1$) ]]; then
            info UPDATE "$FILE" $1
            CONTENT=$(echo "$CONTENT" | sed --expression "s|$VARIABLE=.*|$1|")
        fi

    # $VALUE is empty
    else
        # the variable is actually defined in $CONTENT with an empty value (do nothing)
        if [[ -n $(echo "$CONTENT" | grep ^$VARIABLE=$) ]]; then
            true

        # the variable is actually defined in $CONTENT with a defined value
        else
            # the env var ENV_FILE_EMPTY_OVERWRITE=1 (clear existing value)
            if [[ -n $(printenv | grep "^ENV_FILE_EMPTY_OVERWRITE=1") ]]; then
                info RESET "$FILE" $1
                CONTENT=$(echo "$CONTENT" | sed --expression "s|$VARIABLE=.*|$1|")
            fi 
        fi
    fi
}

# append the line `$1` to `$CONTENT`
append_cont() {
    # https://stackoverflow.com/a/35890017
    # conditional assignment

    # https://unix.stackexchange.com/a/20039
    # insert newline using `$''`
    info CREATE "$FILE" $1

    [[ -z "$CONTENT" ]] \
        && CONTENT=$1 \
        || CONTENT=$CONTENT$'\n'$1
}

# $CONTENT was already defined
inject() {
    # https://linuxize.com/post/how-to-check-if-string-contains-substring-in-bash/
    # check if $1 contains a `=`
    if grep -q = <<< "$1";
    then
        # extract the variable name
        local VARIABLE=$(echo $1 | cut -f 1 -d =)

        # find the line in `$CONTENT` where $1 is defined
        # if the variable line exists, 
        # replace by `$1`, otherwise append `$1`
        [[ -n $(find_cont $VARIABLE) ]] \
            && replace_cont $1 \
            || append_cont $1

    # there is no `=` in $1
    else
        # find the line in printenv where $1 is defined
        local env=$(find_env $1)
        
        # if the line exists in `printenv`
        if [[ -n "$env" ]];
        then

            # find the line in `$CONTENT` where $1 is defined
            # if the variable line exists, 
            # replace by `$env`, otherwise append `$env`
            [[ -n $(find_cont $1) ]] \
                && replace_cont $env \
                || append_cont $env
        fi
    fi

}

FILE=$(realpath --no-symlinks "$1")

if [[ -f "$FILE" ]];
then
    CONTENT=$(cat "$FILE")
else
    CONTENT=
fi

while read l; do
    inject "$l"
done < <(tr -s ' ' '\n' <<< ${@:2})

echo -n "$CONTENT" > "$FILE"
