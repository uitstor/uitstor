#!/bin/bash -e
#

set -E
set -o pipefail

if [ ! -x "$PWD/uitstor" ]; then
    echo "uitstor executable binary not found in current directory"
    exit 1
fi

WORK_DIR="$PWD/.verify-$RANDOM"
MINIO_CONFIG_DIR="$WORK_DIR/.uitstor"
MINIO=( "$PWD/uitstor" --config-dir "$MINIO_CONFIG_DIR" server )

function start_uitstor_3_node() {
    export MINIO_ROOT_USER=uitstor
    export MINIO_ROOT_PASSWORD=uitstor123
    export MINIO_ERASURE_SET_DRIVE_COUNT=6
    export MINIO_CI_CD=1

    start_port=$2
    args=""
    for i in $(seq 1 3); do
	args="$args http://127.0.0.1:$[$start_port+$i]${WORK_DIR}/$i/1/ http://127.0.0.1:$[$start_port+$i]${WORK_DIR}/$i/2/ http://127.0.0.1:$[$start_port+$i]${WORK_DIR}/$i/3/ http://127.0.0.1:$[$start_port+$i]${WORK_DIR}/$i/4/ http://127.0.0.1:$[$start_port+$i]${WORK_DIR}/$i/5/ http://127.0.0.1:$[$start_port+$i]${WORK_DIR}/$i/6/"
    done

    "${MINIO[@]}" --address ":$[$start_port+1]" $args > "${WORK_DIR}/dist-uitstor-server1.log" 2>&1 &
    pid1=$!
    disown ${pid1}

    "${MINIO[@]}" --address ":$[$start_port+2]" $args > "${WORK_DIR}/dist-uitstor-server2.log" 2>&1 &
    pid2=$!
    disown $pid2

    "${MINIO[@]}" --address ":$[$start_port+3]" $args > "${WORK_DIR}/dist-uitstor-server3.log" 2>&1 &
    pid3=$!
    disown $pid3

    sleep "$1"

    if ! ps -p $pid1 1>&2 > /dev/null; then
	echo "server1 log:"
	cat "${WORK_DIR}/dist-uitstor-server1.log"
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
    fi

    if ! ps -p $pid2 1>&2 > /dev/null; then
	echo "server2 log:"
	cat "${WORK_DIR}/dist-uitstor-server2.log"
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
    fi

    if ! ps -p $pid3 1>&2 > /dev/null; then
	echo "server3 log:"
	cat "${WORK_DIR}/dist-uitstor-server3.log"
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
    fi

    if ! pkill uitstor; then
	for i in $(seq 1 3); do
	    echo "server$i log:"
	    cat "${WORK_DIR}/dist-uitstor-server$i.log"
	done
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
    fi

    sleep 1;
    if pgrep uitstor; then
	# forcibly killing, to proceed further properly.
	if ! pkill -9 uitstor; then
	    echo "no uitstor process running anymore, proceed."
	fi
    fi
}


function check_online() {
    if grep -q 'Unable to initialize sub-systems' ${WORK_DIR}/dist-uitstor-*.log; then
	echo "1"
    fi
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

    ## version is purposefully set to '3' for uitstor to migrate configuration file
    echo '{"version": "3", "credential": {"accessKey": "uitstor", "secretKey": "uitstor123"}, "region": "us-east-1"}' > "$MINIO_CONFIG_DIR/config.json"
}

function perform_test() {
    start_uitstor_3_node 120 $2

    echo "Testing Distributed Erasure setup healing of drives"
    echo "Remove the contents of the disks belonging to '${1}' erasure set"

    rm -rf ${WORK_DIR}/${1}/*/

    start_uitstor_3_node 120 $2

    rv=$(check_online)
    if [ "$rv" == "1" ]; then
	for i in $(seq 1 3); do
	    echo "server$i log:"
	    cat "${WORK_DIR}/dist-uitstor-server$i.log"
	done
	pkill -9 uitstor
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
    fi
}

function main()
{
    # use same ports for all tests
    start_port=$(shuf -i 10000-65000 -n 1)

    perform_test "2" ${start_port}
    perform_test "1" ${start_port}
    perform_test "3" ${start_port}
}

( __init__ "$@" && main "$@" )
rv=$?
purge "$WORK_DIR"
exit "$rv"
