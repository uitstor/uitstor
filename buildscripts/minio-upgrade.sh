#!/bin/bash

trap 'cleanup $LINENO' ERR

# shellcheck disable=SC2120
cleanup() {
    MINIO_VERSION=dev docker-compose \
                 -f "buildscripts/upgrade-tests/compose.yml" \
                 rm -s -f
    docker volume prune -f
}

verify_checksum_after_heal() {
    local sum1
    sum1=$(curl -s "$2" | sha256sum);
    mc admin heal --json -r "$1" >/dev/null; # test after healing
    local sum1_heal
    sum1_heal=$(curl -s "$2" | sha256sum);

    if [ "${sum1_heal}" != "${sum1}" ]; then
        echo "mismatch expected ${sum1_heal}, got ${sum1}"
        exit 1;
    fi
}

verify_checksum_mc() {
    local expected
    expected=$(mc cat "$1" | sha256sum)
    local got
    got=$(mc cat "$2" | sha256sum)

    if [ "${expected}" != "${got}" ]; then
        echo "mismatch - expected ${expected}, got ${got}"
        exit 1;
    fi
    echo "matches - ${expected}, got ${got}"
}

add_alias() {
    for i in $(seq 1 4); do
        echo "... attempting to add alias $i"
        until (mc alias set uitstor http://127.0.0.1:9000 uitstoradmin uitstoradmin); do
            echo "...waiting... for 5secs" && sleep 5
        done
    done

    echo "Sleeping for nginx"
    sleep 20
}

__init__() {
    sudo apt install curl -y
    export GOPATH=/tmp/gopath
    export PATH=${PATH}:${GOPATH}/bin

    go install github.com/minio/mc@latest

    TAG=uitstor/uitstor:dev make docker

    MINIO_VERSION=RELEASE.2019-12-19T22-52-26Z docker-compose \
                 -f "buildscripts/upgrade-tests/compose.yml" \
                 up -d --build

    add_alias

    mc mb uitstor/uitstor-test/
    mc cp ./uitstor uitstor/uitstor-test/to-read/
    mc cp /etc/hosts uitstor/uitstor-test/to-read/hosts
    mc policy set download uitstor/uitstor-test

    verify_checksum_mc ./uitstor uitstor/uitstor-test/to-read/uitstor

    curl -s http://127.0.0.1:9000/uitstor-test/to-read/hosts | sha256sum

    MINIO_VERSION=dev docker-compose -f "buildscripts/upgrade-tests/compose.yml" stop
}

main() {
    MINIO_VERSION=dev docker-compose -f "buildscripts/upgrade-tests/compose.yml" up -d --build

    add_alias

    verify_checksum_after_heal uitstor/uitstor-test http://127.0.0.1:9000/uitstor-test/to-read/hosts

    verify_checksum_mc ./uitstor uitstor/uitstor-test/to-read/uitstor

    verify_checksum_mc /etc/hosts uitstor/uitstor-test/to-read/hosts

    cleanup
}

( __init__ "$@" && main "$@" )
