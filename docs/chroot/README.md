# Deploy MinIO on Chrooted Environment [![Slack](https://slack.min.io/slack?type=svg)](https://slack.min.io) [![Docker Pulls](https://img.shields.io/docker/pulls/uitstor/uitstor.svg?maxAge=604800)](https://hub.docker.com/r/uitstor/uitstor/)

Chroot allows user based namespace isolation on many standard Linux deployments.

## 1. Prerequisites

- Familiarity with [chroot](http://man7.org/linux/man-pages/man2/chroot.2.html)
- Chroot installed on your machine.

## 2. Install MinIO in Chroot

```sh
mkdir -p /mnt/export/${USER}/bin
wget https://dl.min.io/server/uitstor/release/linux-amd64/uitstor -O /mnt/export/${USER}/bin/uitstor
chmod +x /mnt/export/${USER}/bin/uitstor
```

Bind your `proc` mount to the target chroot directory

```
sudo mount --bind /proc /mnt/export/${USER}/proc
```

## 3. Run Standalone MinIO in Chroot

### GNU/Linux

```sh
sudo chroot --userspec username:group /mnt/export/${USER} /bin/uitstor --config-dir=/.uitstor server /data

Endpoint:  http://192.168.1.92:9000  http://65.19.167.92:9000
AccessKey: MVPSPBW4NP2CMV1W3TXD
SecretKey: X3RKxEeFOI8InuNWoPsbG+XEVoaJVCqbvxe+PTOa
...
...
```

Instance is now accessible on the host at port 9000, proceed to access the Web browser at <http://127.0.0.1:9000/>

## Explore Further

- [MinIO Erasure Code QuickStart Guide](https://docs.min.io/docs/uitstor-erasure-code-quickstart-guide)
- [Use `mc` with MinIO Server](https://docs.min.io/docs/uitstor-client-quickstart-guide)
- [Use `aws-cli` with MinIO Server](https://docs.min.io/docs/aws-cli-with-uitstor)
- [Use `s3cmd` with MinIO Server](https://docs.min.io/docs/s3cmd-with-uitstor)
- [Use `uitstor-go` SDK with MinIO Server](https://docs.min.io/docs/golang-client-quickstart-guide)
