#!/bin/bash -e

set -E
set -o pipefail
set -x

WORK_DIR="$PWD/.verify-$RANDOM"
MINIO_CONFIG_DIR="$WORK_DIR/.uitstor"
MINIO=( "$PWD/uitstor" --config-dir "$MINIO_CONFIG_DIR" server )

if [ ! -x "$PWD/uitstor" ]; then
    echo "uitstor executable binary not found in current directory"
    exit 1
fi

function start_uitstor_5drive() {
    start_port=$1

    export MINIO_ROOT_USER=uitstor
    export MINIO_ROOT_PASSWORD=uitstor123
    export MC_HOST_uitstor="http://uitstor:uitstor123@127.0.0.1:${start_port}/"
    unset MINIO_KMS_AUTO_ENCRYPTION # do not auto-encrypt objects
    export MINIO_CI_CD=1

    MC_BUILD_DIR="mc-$RANDOM"
    if ! git clone --quiet https://github.com/minio/mc "$MC_BUILD_DIR"; then
	echo "failed to download https://github.com/minio/mc"
	purge "${MC_BUILD_DIR}"
	exit 1
    fi

    (cd "${MC_BUILD_DIR}" && go build -o "$WORK_DIR/mc")

    # remove mc source.
    purge "${MC_BUILD_DIR}"

    "${WORK_DIR}/mc" cp --quiet -r "buildscripts/cicd-corpus/" "${WORK_DIR}/cicd-corpus/"

    "${MINIO[@]}" --address ":$start_port" "${WORK_DIR}/cicd-corpus/disk{1...5}" > "${WORK_DIR}/server1.log" 2>&1 &
    pid=$!
    disown $pid
    sleep 30

    if ! ps -p ${pid} 1>&2 >/dev/null; then
	echo "server1 log:"
	cat "${WORK_DIR}/server1.log"
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
    fi

    "${WORK_DIR}/mc" stat uitstor/bucket/testobj

    pkill uitstor
    sleep 3
}

function main() {
    start_port=$(shuf -i 10000-65000 -n 1)

    start_uitstor_5drive ${start_port}
}

function purge()
{
    rm -rf "$1"
}

( main "$@" )
rv=$?
purge "$WORK_DIR"
exit "$rv"
