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
    rm -rf /tmp/uitstor{1,2,3}
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
export MINIO_IDENTITY_OPENID_CONFIG_URL="http://localhost:5556/dex/.well-known/openid-configuration"
export MINIO_IDENTITY_OPENID_CLIENT_ID="uitstor-client-app"
export MINIO_IDENTITY_OPENID_CLIENT_SECRET="uitstor-client-app-secret"
export MINIO_IDENTITY_OPENID_CLAIM_NAME="groups"
export MINIO_IDENTITY_OPENID_SCOPES="openid,groups"

export MINIO_IDENTITY_OPENID_REDIRECT_URI="http://127.0.0.1:10000/oauth_callback"
uitstor server --address ":9001" --console-address ":10000" /tmp/uitstor1/{1...4} >/tmp/uitstor1_1.log 2>&1 &
site1_pid=$!
export MINIO_IDENTITY_OPENID_REDIRECT_URI="http://127.0.0.1:11000/oauth_callback"
uitstor server --address ":9002" --console-address ":11000" /tmp/uitstor2/{1...4} >/tmp/uitstor2_1.log 2>&1 &
site2_pid=$!

export MINIO_IDENTITY_OPENID_REDIRECT_URI="http://127.0.0.1:12000/oauth_callback"
uitstor server --address ":9003" --console-address ":12000" /tmp/uitstor3/{1...4} >/tmp/uitstor3_1.log 2>&1 &
site3_pid=$!

if [ ! -f ./mc ]; then
    wget -O mc https://dl.uitstor.io/client/mc/release/linux-amd64/mc \
        && chmod +x mc
fi

sleep 10

export MC_HOST_uitstor1=http://uitstor:uitstor123@localhost:9001
export MC_HOST_uitstor2=http://uitstor:uitstor123@localhost:9002
export MC_HOST_uitstor3=http://uitstor:uitstor123@localhost:9003

./mc admin replicate add uitstor1 uitstor2 uitstor3

./mc admin policy add uitstor1 projecta ./docs/site-replication/rw.json
sleep 5

./mc admin policy info uitstor2 projecta >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "expecting the command to succeed, exiting.."
    exit_1;
fi
./mc admin policy info uitstor3 projecta >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "expecting the command to succeed, exiting.."
    exit_1;
fi

./mc admin policy remove uitstor3 projecta

sleep 10
./mc admin policy info uitstor1 projecta
if [ $? -eq 0 ]; then
    echo "expecting the command to fail, exiting.."
    exit_1;
fi

./mc admin policy info uitstor2 projecta
if [ $? -eq 0 ]; then
    echo "expecting the command to fail, exiting.."
    exit_1;
fi

./mc admin policy add uitstor1 projecta ./docs/site-replication/rw.json
sleep 5

# Generate STS credential with STS call to uitstor1
STS_CRED=$(MINIO_ENDPOINT=http://localhost:9001 go run ./docs/site-replication/gen-oidc-sts-cred.go)

MC_HOST_foo=http://${STS_CRED}@localhost:9001 ./mc ls foo
if [ $? -ne 0 ]; then
    echo "Expected sts credential to work, exiting.."
    exit_1;
fi

sleep 2

# Check that the STS credential works on uitstor2 and uitstor3.
MC_HOST_foo=http://${STS_CRED}@localhost:9002 ./mc ls foo
if [ $? -ne 0 ]; then
    echo "Expected sts credential to work, exiting.."
    exit_1;
fi

MC_HOST_foo=http://${STS_CRED}@localhost:9003 ./mc ls foo
if [ $? -ne 0 ]; then
    echo "Expected sts credential to work, exiting.."
    exit_1;
fi

STS_ACCESS_KEY=$(echo ${STS_CRED} | cut -d ':' -f 1)

# Create service account for STS user
./mc admin user svcacct add uitstor2 $STS_ACCESS_KEY --access-key testsvc --secret-key testsvc123
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
# stop uitstor1 instance
kill -9 ${site1_pid}
# Update tag on uitstor2/newbucket when uitstor1 is down
./mc tag set uitstor2/newbucket "key=val2"
# create a new bucket on uitstor2. This should replicate to uitstor1 after it comes online.
./mc mb uitstor2/newbucket2

# Restart uitstor1 instance
uitstor server --address ":9001" --console-address ":10000" /tmp/uitstor1/{1...4} >/tmp/uitstor1_1.log 2>&1 &
sleep 10
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
