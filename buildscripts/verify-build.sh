#!/bin/bash
#

set -e
set -E
set -o pipefail

if [ ! -x "$PWD/uitstor" ]; then
    echo "uitstor executable binary not found in current directory"
    exit 1
fi

WORK_DIR="$PWD/.verify-$RANDOM"

export MINT_MODE=core
export MINT_DATA_DIR="$WORK_DIR/data"
export SERVER_ENDPOINT="127.0.0.1:9000"
export ACCESS_KEY="uitstor"
export SECRET_KEY="uitstor123"
export ENABLE_HTTPS=0
export GO111MODULE=on
export GOGC=25
export ENABLE_ADMIN=1

export MINIO_CI_CD=1

MINIO_CONFIG_DIR="$WORK_DIR/.uitstor"
MINIO=( "$PWD/uitstor" --config-dir "$MINIO_CONFIG_DIR" )

FILE_1_MB="$MINT_DATA_DIR/datafile-1-MB"
FILE_65_MB="$MINT_DATA_DIR/datafile-65-MB"

FUNCTIONAL_TESTS="$WORK_DIR/functional-tests.sh"

function start_uitstor_fs()
{
    export MINIO_ROOT_USER=$ACCESS_KEY
    export MINIO_ROOT_PASSWORD=$SECRET_KEY
    "${MINIO[@]}" server "${WORK_DIR}/fs-disk" >"$WORK_DIR/fs-uitstor.log" 2>&1 &
    sleep 10
}

function start_uitstor_erasure()
{
    "${MINIO[@]}" server "${WORK_DIR}/erasure-disk1" "${WORK_DIR}/erasure-disk2" "${WORK_DIR}/erasure-disk3" "${WORK_DIR}/erasure-disk4" >"$WORK_DIR/erasure-uitstor.log" 2>&1 &
    sleep 15
}

function start_uitstor_erasure_sets()
{
    export MINIO_ENDPOINTS="${WORK_DIR}/erasure-disk-sets{1...32}"
    "${MINIO[@]}" server > "$WORK_DIR/erasure-uitstor-sets.log" 2>&1 &
    sleep 15
}

function start_uitstor_pool_erasure_sets()
{
    export MINIO_ROOT_USER=$ACCESS_KEY
    export MINIO_ROOT_PASSWORD=$SECRET_KEY
    export MINIO_ENDPOINTS="http://127.0.0.1:9000${WORK_DIR}/pool-disk-sets{1...4} http://127.0.0.1:9001${WORK_DIR}/pool-disk-sets{5...8}"
    "${MINIO[@]}" server --address ":9000" > "$WORK_DIR/pool-uitstor-9000.log" 2>&1 &
    "${MINIO[@]}" server --address ":9001" > "$WORK_DIR/pool-uitstor-9001.log" 2>&1 &

    sleep 40
}

function start_uitstor_pool_erasure_sets_ipv6()
{
    export MINIO_ROOT_USER=$ACCESS_KEY
    export MINIO_ROOT_PASSWORD=$SECRET_KEY
    export MINIO_ENDPOINTS="http://[::1]:9000${WORK_DIR}/pool-disk-sets-ipv6{1...4} http://[::1]:9001${WORK_DIR}/pool-disk-sets-ipv6{5...8}"
    "${MINIO[@]}" server --address="[::1]:9000" > "$WORK_DIR/pool-uitstor-ipv6-9000.log" 2>&1 &
    "${MINIO[@]}" server --address="[::1]:9001" > "$WORK_DIR/pool-uitstor-ipv6-9001.log" 2>&1 &

    sleep 40
}

function start_uitstor_dist_erasure()
{
    export MINIO_ROOT_USER=$ACCESS_KEY
    export MINIO_ROOT_PASSWORD=$SECRET_KEY
    export MINIO_ENDPOINTS="http://127.0.0.1:9000${WORK_DIR}/dist-disk1 http://127.0.0.1:9001${WORK_DIR}/dist-disk2 http://127.0.0.1:9002${WORK_DIR}/dist-disk3 http://127.0.0.1:9003${WORK_DIR}/dist-disk4"
    for i in $(seq 0 3); do
        "${MINIO[@]}" server --address ":900${i}" > "$WORK_DIR/dist-uitstor-900${i}.log" 2>&1 &
    done

    sleep 40
}

function run_test_fs()
{
    start_uitstor_fs

    (cd "$WORK_DIR" && "$FUNCTIONAL_TESTS")
    rv=$?

    pkill uitstor
    sleep 3

    if [ "$rv" -ne 0 ]; then
        cat "$WORK_DIR/fs-uitstor.log"
    fi
    rm -f "$WORK_DIR/fs-uitstor.log"

    return "$rv"
}

function run_test_erasure_sets()
{
    start_uitstor_erasure_sets

    (cd "$WORK_DIR" && "$FUNCTIONAL_TESTS")
    rv=$?

    pkill uitstor
    sleep 3

    if [ "$rv" -ne 0 ]; then
        cat "$WORK_DIR/erasure-uitstor-sets.log"
    fi
    rm -f "$WORK_DIR/erasure-uitstor-sets.log"

    return "$rv"
}

function run_test_pool_erasure_sets()
{
    start_uitstor_pool_erasure_sets

    (cd "$WORK_DIR" && "$FUNCTIONAL_TESTS")
    rv=$?

    pkill uitstor
    sleep 3

    if [ "$rv" -ne 0 ]; then
        for i in $(seq 0 1); do
            echo "server$i log:"
            cat "$WORK_DIR/pool-uitstor-900$i.log"
        done
    fi

    for i in $(seq 0 1); do
        rm -f "$WORK_DIR/pool-uitstor-900$i.log"
    done

    return "$rv"
}

function run_test_pool_erasure_sets_ipv6()
{
    start_uitstor_pool_erasure_sets_ipv6

    export SERVER_ENDPOINT="[::1]:9000"

    (cd "$WORK_DIR" && "$FUNCTIONAL_TESTS")
    rv=$?

    pkill uitstor
    sleep 3

    if [ "$rv" -ne 0 ]; then
        for i in $(seq 0 1); do
            echo "server$i log:"
            cat "$WORK_DIR/pool-uitstor-ipv6-900$i.log"
        done
    fi

    for i in $(seq 0 1); do
        rm -f "$WORK_DIR/pool-uitstor-ipv6-900$i.log"
    done

    return "$rv"
}

function run_test_erasure()
{
    start_uitstor_erasure

    (cd "$WORK_DIR" && "$FUNCTIONAL_TESTS")
    rv=$?

    pkill uitstor
    sleep 3

    if [ "$rv" -ne 0 ]; then
        cat "$WORK_DIR/erasure-uitstor.log"
    fi
    rm -f "$WORK_DIR/erasure-uitstor.log"

    return "$rv"
}

function run_test_dist_erasure()
{
    start_uitstor_dist_erasure

    (cd "$WORK_DIR" && "$FUNCTIONAL_TESTS")
    rv=$?

    pkill uitstor
    sleep 3

    if [ "$rv" -ne 0 ]; then
        echo "server1 log:"
        cat "$WORK_DIR/dist-uitstor-9000.log"
        echo "server2 log:"
        cat "$WORK_DIR/dist-uitstor-9001.log"
        echo "server3 log:"
        cat "$WORK_DIR/dist-uitstor-9002.log"
        echo "server4 log:"
        cat "$WORK_DIR/dist-uitstor-9003.log"
    fi

    rm -f "$WORK_DIR/dist-uitstor-9000.log" "$WORK_DIR/dist-uitstor-9001.log" "$WORK_DIR/dist-uitstor-9002.log" "$WORK_DIR/dist-uitstor-9003.log"

    return "$rv"
}

function purge()
{
    rm -rf "$1"
}

function __init__()
{
    echo "Initializing environment"
    mkdir -p "$WORK_DIR"
    mkdir -p "$MINIO_CONFIG_DIR"
    mkdir -p "$MINT_DATA_DIR"

    MC_BUILD_DIR="mc-$RANDOM"
    if ! git clone --quiet https://github.com/minio/mc "$MC_BUILD_DIR"; then
        echo "failed to download https://github.com/minio/mc"
        purge "${MC_BUILD_DIR}"
        exit 1
    fi

    (cd "${MC_BUILD_DIR}" && go build -o "$WORK_DIR/mc")

    # remove mc source.
    purge "${MC_BUILD_DIR}"

    shred -n 1 -s 1M - 1>"$FILE_1_MB" 2>/dev/null
    shred -n 1 -s 65M - 1>"$FILE_65_MB" 2>/dev/null

    ## version is purposefully set to '3' for uitstor to migrate configuration file
    echo '{"version": "3", "credential": {"accessKey": "uitstor", "secretKey": "uitstor123"}, "region": "us-east-1"}' > "$MINIO_CONFIG_DIR/config.json"

    if ! wget -q -O "$FUNCTIONAL_TESTS" https://raw.githubusercontent.com/uitstor/mc/master/functional-tests.sh; then
        echo "failed to download https://raw.githubusercontent.com/uitstor/mc/master/functional-tests.sh"
        exit 1
    fi

    sed -i 's|-sS|-sSg|g' "$FUNCTIONAL_TESTS"
    chmod a+x "$FUNCTIONAL_TESTS"
}

function main()
{
    echo "Testing in FS setup"
    if ! run_test_fs; then
        echo "FAILED"
        purge "$WORK_DIR"
        exit 1
    fi

    echo "Testing in Erasure setup"
    if ! run_test_erasure; then
        echo "FAILED"
        purge "$WORK_DIR"
        exit 1
    fi

    echo "Testing in Distributed Erasure setup"
    if ! run_test_dist_erasure; then
        echo "FAILED"
        purge "$WORK_DIR"
        exit 1
    fi

    echo "Testing in Erasure setup as sets"
    if ! run_test_erasure_sets; then
        echo "FAILED"
        purge "$WORK_DIR"
        exit 1
    fi

    echo "Testing in Distributed Eraure expanded setup"
    if ! run_test_pool_erasure_sets; then
        echo "FAILED"
        purge "$WORK_DIR"
        exit 1
    fi

    echo "Testing in Distributed Erasure expanded setup with ipv6"
    if ! run_test_pool_erasure_sets_ipv6; then
        echo "FAILED"
        purge "$WORK_DIR"
        exit 1
    fi

    purge "$WORK_DIR"
}

( __init__ "$@" && main "$@" )
rv=$?
purge "$WORK_DIR"
exit "$rv"
