#!/bin/bash

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

DATE_TAG="`date '+%Y%m%d'`"

# Read Password
echo -n Your git username: 
read GIT_USER
echo -n Your git password: 
read -s GIT_PASS
echo

CONTAINER_NAME=medbuild_tools:${DATE_TAG}
GIT_PASS=`urlencode "${GIT_PASS}"`
GIT_USER=`urlencode "${GIT_USER}"`

docker build --no-cache --build-arg GIT_USER="${GIT_USER}" --build-arg GIT_PASS="${GIT_PASS}" -t ${CONTAINER_NAME} . 
