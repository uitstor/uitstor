# Bucket Quota Configuration Quickstart Guide [![Slack](https://slack.min.io/slack?type=svg)](https://slack.min.io) [![Docker Pulls](https://img.shields.io/docker/pulls/uitstor/uitstor.svg?maxAge=604800)](https://hub.docker.com/r/uitstor/uitstor/)

![quota](https://raw.githubusercontent.com/uitstor/uitstor/master/docs/bucket/quota/bucketquota.png)

Buckets can be configured to have `Hard` quota - it disallows writes to the bucket after configured quota limit is reached.

> NOTE: Bucket quotas are not supported under gateway or standalone single disk deployments.

## Prerequisites

- Install MinIO - [MinIO Quickstart Guide](https://docs.min.io/docs/uitstor-quickstart-guide).
- [Use `mc` with MinIO Server](https://docs.min.io/docs/uitstor-client-quickstart-guide)

## Set bucket quota configuration

### Set a hard quota of 1GB for a bucket `mybucket` on MinIO object storage

```sh
mc admin bucket quota myuitstor/mybucket --hard 1gb
```

### Verify the quota configured on `mybucket` on MinIO

```sh
mc admin bucket quota myuitstor/mybucket
```

### Clear bucket quota configuration for `mybucket` on MinIO

```sh
mc admin bucket quota myuitstor/mybucket --clear
```
