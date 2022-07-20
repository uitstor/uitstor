#!/usr/bin/env bash

# shellcheck disable=SC2120
exit_1() {
    cleanup
    exit 1
}

cleanup() {
    echo "Cleaning up instances of MinIO"
    pkill uitstor
    pkill -9 uitstor
    rm -rf /tmp/uitstor-internal-idp{1,2,3}
}

cleanup

unset MINIO_KMS_KES_CERT_FILE
unset MINIO_KMS_KES_KEY_FILE
unset MINIO_KMS_KES_ENDPOINT
unset MINIO_KMS_KES_KEY_NAME

export MINIO_CI_CD=1
export MINIO_BROWSER=off
export MINIO_ROOT_USER="uitstor"
export MINIO_ROOT_PASSWORD="uitstor123"
export MINIO_KMS_AUTO_ENCRYPTION=off
export MINIO_PROMETHEUS_AUTH_TYPE=public
export MINIO_KMS_SECRET_KEY=my-uitstor-key:OSMM+vkKUTCvQs9YL/CVMIMt43HFhkUpqJxTmGl6rYw=

if [ ! -f ./mc ]; then
    wget -O mc https://dl.uitstor.io/client/mc/release/linux-amd64/mc \
        && chmod +x mc
fi

uitstor server --config-dir /tmp/uitstor-internal --address ":9001" /tmp/uitstor-internal-idp1/{1...4} >/tmp/uitstor1_1.log 2>&1 &
site1_pid=$!
uitstor server --config-dir /tmp/uitstor-internal --address ":9002" /tmp/uitstor-internal-idp2/{1...4} >/tmp/uitstor2_1.log 2>&1 &
site2_pid=$!
uitstor server --config-dir /tmp/uitstor-internal --address ":9003" /tmp/uitstor-internal-idp3/{1...4} >/tmp/uitstor3_1.log 2>&1 &
site3_pid=$!

sleep 10

export MC_HOST_uitstor1=http://uitstor:uitstor123@localhost:9001
export MC_HOST_uitstor2=http://uitstor:uitstor123@localhost:9002
export MC_HOST_uitstor3=http://uitstor:uitstor123@localhost:9003

./mc admin replicate add uitstor1 uitstor2

./mc admin user add uitstor1 foobar foo12345

## add foobar-g group with foobar
./mc admin group add uitstor2 foobar-g foobar

./mc admin policy set uitstor1 consoleAdmin user=foobar
sleep 5

./mc admin user info uitstor2 foobar

./mc admin group info uitstor1 foobar-g

./mc admin policy add uitstor1 rw ./docs/site-replication/rw.json

sleep 5
./mc admin policy info uitstor2 rw >/dev/null 2>&1

./mc admin replicate status uitstor1

## Add a new empty site
./mc admin replicate add uitstor1 uitstor2 uitstor3

sleep 10

./mc admin policy info uitstor3 rw >/dev/null 2>&1

./mc admin policy remove uitstor3 rw

./mc admin replicate status uitstor3

sleep 10

./mc admin policy info uitstor1 rw
if [ $? -eq 0 ]; then
    echo "expecting the command to fail, exiting.."
    exit_1;
fi

./mc admin policy info uitstor2 rw
if [ $? -eq 0 ]; then
    echo "expecting the command to fail, exiting.."
    exit_1;
fi

./mc admin policy info uitstor3 rw
if [ $? -eq 0 ]; then
    echo "expecting the command to fail, exiting.."
    exit_1;
fi

./mc admin user info uitstor1 foobar
if [ $? -ne 0 ]; then
    echo "policy mapping missing on 'uitstor1', exiting.."
    exit_1;
fi

./mc admin user info uitstor2 foobar
if [ $? -ne 0 ]; then
    echo "policy mapping missing on 'uitstor2', exiting.."
    exit_1;
fi

./mc admin user info uitstor3 foobar
if [ $? -ne 0 ]; then
    echo "policy mapping missing on 'uitstor3', exiting.."
    exit_1;
fi

./mc admin group info uitstor3 foobar-g
if [ $? -ne 0 ]; then
    echo "group mapping missing on 'uitstor3', exiting.."
    exit_1;
fi

./mc admin user svcacct add uitstor2 foobar --access-key testsvc --secret-key testsvc123
if [ $? -ne 0 ]; then
    echo "adding svc account failed, exiting.."
    exit_1;
fi

sleep 10

./mc admin user svcacct info uitstor1 testsvc
if [ $? -ne 0 ]; then
    echo "svc account not mirrored, exiting.."
    exit_1;
fi

./mc admin user svcacct info uitstor2 testsvc
if [ $? -ne 0 ]; then
    echo "svc account not mirrored, exiting.."
    exit_1;
fi

./mc admin user svcacct rm uitstor1 testsvc
if [ $? -ne 0 ]; then
    echo "removing svc account failed, exiting.."
    exit_1;
fi

sleep 10
./mc admin user svcacct info uitstor2 testsvc
if [ $? -eq 0 ]; then
    echo "svc account found after delete, exiting.."
    exit_1;
fi

./mc admin user svcacct info uitstor3 testsvc
if [ $? -eq 0 ]; then
    echo "svc account found after delete, exiting.."
    exit_1;
fi

./mc mb uitstor1/newbucket

sleep 5
./mc stat uitstor2/newbucket
if [ $? -ne 0 ]; then
    echo "expecting bucket to be present. exiting.."
    exit_1;
fi

./mc stat uitstor3/newbucket
if [ $? -ne 0 ]; then
    echo "expecting bucket to be present. exiting.."
    exit_1;
fi

err_uitstor2=$(./mc stat uitstor2/newbucket/xxx --json | jq -r .error.cause.message)
if [ $? -ne 0 ]; then
    echo "expecting object to be missing. exiting.."
    exit_1;
fi

if [ "${err_uitstor2}" != "Object does not exist" ]; then
    echo "expected to see Object does not exist error, exiting..."
    exit_1;
fi

./mc cp README.md uitstor2/newbucket/

sleep 5
./mc stat uitstor1/newbucket/README.md
if [ $? -ne 0 ]; then
    echo "expecting object to be present. exiting.."
    exit_1;
fi

./mc stat uitstor3/newbucket/README.md
if [ $? -ne 0 ]; then
    echo "expecting object to be present. exiting.."
    exit_1;
fi

vID=$(./mc stat uitstor2/newbucket/README.md --json | jq .versionID)
if [ $? -ne 0 ]; then
    echo "expecting object to be present. exiting.."
    exit_1;
fi
./mc tag set --version-id "${vID}" uitstor2/newbucket/README.md "k=v"
if [ $? -ne 0 ]; then
    echo "expecting tag set to be successful. exiting.."
    exit_1;
fi
sleep 5

./mc tag remove --version-id "${vID}" uitstor2/newbucket/README.md
if [ $? -ne 0 ]; then
    echo "expecting tag removal to be successful. exiting.."
    exit_1;
fi
sleep 5

replStatus_uitstor2=$(./mc stat uitstor2/newbucket/README.md --json | jq -r .replicationStatus )
if [ $? -ne 0 ]; then
    echo "expecting object to be present. exiting.."
    exit_1;
fi

if [ ${replStatus_uitstor2} != "COMPLETED" ]; then
    echo "expected tag removal to have replicated, exiting..."
    exit_1;
fi

./mc rm uitstor3/newbucket/README.md
sleep 5

./mc stat uitstor2/newbucket/README.md
if [ $? -eq 0 ]; then
    echo "expected file to be deleted, exiting.."
    exit_1;
fi

./mc stat uitstor1/newbucket/README.md
if [ $? -eq 0 ]; then
    echo "expected file to be deleted, exiting.."
    exit_1;
fi

./mc mb --with-lock uitstor3/newbucket-olock
sleep 5

enabled_uitstor2=$(./mc stat --json uitstor2/newbucket-olock| jq -r .metadata.ObjectLock.enabled)
if [ $? -ne 0 ]; then
    echo "expected bucket to be mirrored with object-lock but not present, exiting..."
    exit_1;
fi

if [ "${enabled_uitstor2}" != "Enabled" ]; then
    echo "expected bucket to be mirrored with object-lock enabled, exiting..."
    exit_1;
fi

enabled_uitstor1=$(./mc stat --json uitstor1/newbucket-olock| jq -r .metadata.ObjectLock.enabled)
if [ $? -ne 0 ]; then
    echo "expected bucket to be mirrored with object-lock but not present, exiting..."
    exit_1;
fi

if [ "${enabled_uitstor1}" != "Enabled" ]; then
    echo "expected bucket to be mirrored with object-lock enabled, exiting..."
    exit_1;
fi

# "Test if most recent tag update is replicated"
./mc tag set uitstor2/newbucket "key=val1"
if [ $? -ne 0 ]; then
    echo "expecting tag set to be successful. exiting.."
    exit_1;
fi
sleep 5

val=$(./mc tag list uitstor1/newbucket --json | jq -r .tagset | jq -r .key)
if [ "${val}" != "val1" ]; then
    echo "expected bucket tag to have replicated, exiting..."
    exit_1;
fi
# Create user with policy consoleAdmin on uitstor1
./mc admin user add uitstor1 foobarx foobar123
if [ $? -ne 0 ]; then
    echo "adding user failed, exiting.."
    exit_1;
fi
./mc admin policy set uitstor1 consoleAdmin user=foobarx
if [ $? -ne 0 ]; then
    echo "adding policy mapping failed, exiting.."
    exit_1;
fi
sleep 10

# unset policy for foobarx in uitstor2
./mc admin policy unset uitstor2 consoleAdmin user=foobarx
if [ $? -ne 0 ]; then
    echo "unset policy mapping failed, exiting.."
    exit_1;
fi

sleep 10

# Test whether policy unset replicated to uitstor1
policy=$(./mc admin user info uitstor1 foobarx --json | jq -r .policyName)
if [ "${policy}" != "null" ]; then
    echo "expected policy unset to have replicated, exiting..."
    exit_1;
fi

kill -9 ${site1_pid}
# Update tag on uitstor2/newbucket when uitstor1 is down
./mc tag set uitstor2/newbucket "key=val2"
# create a new bucket on uitstor2. This should replicate to uitstor1 after it comes online.
./mc mb uitstor2/newbucket2
# Restart uitstor1 instance
uitstor server --config-dir /tmp/uitstor-internal --address ":9001" /tmp/uitstor-internal-idp1/{1...4} >/tmp/uitstor1_1.log 2>&1 &
sleep 15

# Test whether most recent tag update on uitstor2 is replicated to uitstor1
val=$(./mc tag list uitstor1/newbucket --json | jq -r .tagset | jq -r .key )
if [ "${val}" != "val2" ]; then
    echo "expected bucket tag to have replicated, exiting..."
    exit_1;
fi
# Test if bucket created when uitstor1 is down healed
diff -q <(./mc ls uitstor1 | awk '{print $3}') <(./mc ls uitstor2 | awk '{print $3}') 1>/dev/null
if  [ $? -ne 0 ]; then
    echo "expected bucket to have replicated, exiting..."
    exit_1;
fi