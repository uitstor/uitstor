#!/bin/bash

if [ -n "$TEST_DEBUG" ]; then
    set -x
fi

pkill uitstor
rm -rf /tmp/xl

if [ ! -f ./mc ]; then
    wget --quiet -O mc https://dl.uitstor.io/client/mc/release/linux-amd64/mc && \
	chmod +x mc
fi

export CI=true

(uitstor server /tmp/xl/{1...10}/disk{0...1} 2>&1 >/dev/null)&
pid=$!

sleep 2

export MC_HOST_myuitstor="http://uitstoradmin:uitstoradmin@localhost:9000/"

./mc admin user add myuitstor/ uitstor123 uitstor123
./mc admin user add myuitstor/ uitstor12345 uitstor12345

./mc admin policy add myuitstor/ rw ./docs/distributed/rw.json
./mc admin policy add myuitstor/ lake ./docs/distributed/rw.json

./mc admin policy set myuitstor/ rw user=uitstor123
./mc admin policy set myuitstor/ lake,rw user=uitstor12345

./mc mb -l myuitstor/versioned

./mc mirror internal myuitstor/versioned/ --quiet >/dev/null

## Soft delete (creates delete markers)
./mc rm -r --force myuitstor/versioned >/dev/null

## mirror again to create another set of version on top
./mc mirror internal myuitstor/versioned/ --quiet >/dev/null

expected_checksum=$(./mc cat internal/dsync/drwmutex.go | md5sum)

user_count=$(./mc admin user list myuitstor/ | wc -l)
policy_count=$(./mc admin policy list myuitstor/ | wc -l)

kill $pid
(uitstor server /tmp/xl/{1...10}/disk{0...1} /tmp/xl/{11...30}/disk{0...3} 2>&1 >/tmp/expanded.log) &
pid=$!

sleep 2

expanded_user_count=$(./mc admin user list myuitstor/ | wc -l)
expanded_policy_count=$(./mc admin policy list myuitstor/ | wc -l)

if [ $user_count -ne $expanded_user_count ]; then
    echo "BUG: original user count differs from expanded setup"
    exit 1
fi

if [ $policy_count -ne $expanded_policy_count ]; then
    echo "BUG: original policy count  differs from expanded setup"
    exit 1
fi

./mc version info myuitstor/versioned | grep -q "versioning is enabled"
ret=$?
if [ $ret -ne 0 ]; then
    echo "expected versioning enabled after expansion"
    exit 1
fi

./mc mirror cmd myuitstor/versioned/ --quiet >/dev/null

./mc ls -r myuitstor/versioned/ > expanded_ns.txt
./mc ls -r --versions myuitstor/versioned/ > expanded_ns_versions.txt

./mc admin decom start myuitstor/ /tmp/xl/{1...10}/disk{0...1}

until $(./mc admin decom status myuitstor/ | grep -q Complete)
do
    echo "waiting for decom to finish..."
    sleep 1
done

kill $pid

(uitstor server /tmp/xl/{11...30}/disk{0...3} 2>&1 >/dev/null)&
pid=$!

sleep 2

decom_user_count=$(./mc admin user list myuitstor/ | wc -l)
decom_policy_count=$(./mc admin policy list myuitstor/ | wc -l)

if [ $user_count -ne $decom_user_count ]; then
    echo "BUG: original user count differs after decommission"
    exit 1
fi

if [ $policy_count -ne $decom_policy_count ]; then
    echo "BUG: original policy count differs after decommission"
    exit 1
fi

./mc version info myuitstor/versioned | grep -q "versioning is enabled"
ret=$?
if [ $ret -ne 0 ]; then
    echo "BUG: expected versioning enabled after decommission"
    exit 1
fi

./mc ls -r myuitstor/versioned > decommissioned_ns.txt
./mc ls -r --versions myuitstor/versioned > decommissioned_ns_versions.txt

out=$(diff -qpruN expanded_ns.txt decommissioned_ns.txt)
ret=$?
if [ $ret -ne 0 ]; then
    echo "BUG: expected no missing entries after decommission: $out"
    exit 1
fi

out=$(diff -qpruN expanded_ns_versions.txt decommissioned_ns_versions.txt)
ret=$?
if [ $ret -ne 0 ]; then
    echo "BUG: expected no missing entries after decommission: $out"
    exit 1
fi

got_checksum=$(./mc cat myuitstor/versioned/dsync/drwmutex.go | md5sum)
if [ "${expected_checksum}" != "${got_checksum}" ]; then
    echo "BUG: decommission failed on encrypted objects: expected ${expected_checksum} got ${got_checksum}"
    exit 1
fi

kill $pid
