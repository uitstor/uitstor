#!/bin/sh
#

set -e

if [ ! -x "/opt/bin/uitstor" ]; then
    echo "uitstor executable binary not found refusing to proceed"
    exit 1
fi

verify_sha256sum() {
    echo "verifying binary checksum"
    echo "$(awk '{print $1}' /opt/bin/uitstor.sha256sum)  /opt/bin/uitstor" | sha256sum -c
}

verify_signature() {
    if [ "${TARGETARCH}" = "arm" ]; then
        echo "ignoring verification of binary signature"
        return
    fi
    echo "verifying binary signature"
    minisign -VQm /opt/bin/uitstor -P RWTx5Zr1tiHQLwG9keckT0c45M3AGeHD6IvimQHpyRywVWGbP1aVSGav
}

main() {
    verify_sha256sum

    verify_signature
}

main "$@"
