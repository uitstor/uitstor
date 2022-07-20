# List of metrics reported cluster wide

Each metric includes a label for the server that calculated the metric.
Each metric has a label for the server that generated the metric.

These metrics can be from any MinIO server once per collection.

| Name                                         | Description                                                                                                         |
|:---------------------------------------------|:--------------------------------------------------------------------------------------------------------------------|
| `uitstor_bucket_objects_size_distribution`     | Distribution of object sizes in the bucket, includes label for the bucket name.                                     |
| `uitstor_bucket_replication_failed_bytes`      | Total number of bytes failed at least once to replicate.                                                            |
| `uitstor_bucket_replication_received_bytes`    | Total number of bytes replicated to this bucket from another source bucket.                                         |
| `uitstor_bucket_replication_sent_bytes`        | Total number of bytes replicated to the target bucket.                                                              |
| `uitstor_bucket_replication_failed_count`      | Total number of replication foperations failed for this bucket.                                                     |
| `uitstor_bucket_usage_object_total`            | Total number of objects                                                                                             |
| `uitstor_bucket_usage_total_bytes`             | Total bucket size in bytes                                                                                          |
| `uitstor_bucket_quota_total_bytes`             | Total bucket quota size in bytes                                                                                    |
| `uitstor_bucket_traffic_sent_bytes`            | Total s3 bytes sent per bucket                                                                                      |
| `uitstor_bucket_traffic_received_bytes`        | Total s3 bytes received per bucket                                                                                  |
| `uitstor_cache_hits_total`                     | Total number of disk cache hits                                                                                     |
| `uitstor_cache_missed_total`                   | Total number of disk cache misses                                                                                   |
| `uitstor_cache_sent_bytes`                     | Total number of bytes served from cache                                                                             |
| `uitstor_cache_total_bytes`                    | Total size of cache disk in bytes                                                                                   |
| `uitstor_cache_usage_info`                     | Total percentage cache usage, value of 1 indicates high and 0 low, label level is set as well                       |
| `uitstor_cache_used_bytes`                     | Current cache usage in bytes                                                                                        |
| `uitstor_cluster_capacity_raw_free_bytes`      | Total free capacity online in the cluster.                                                                          |
| `uitstor_cluster_capacity_raw_total_bytes`     | Total capacity online in the cluster.                                                                               |
| `uitstor_cluster_capacity_usable_free_bytes`   | Total free usable capacity online in the cluster.                                                                   |
| `uitstor_cluster_capacity_usable_total_bytes`  | Total usable capacity online in the cluster.                                                                        |
| `uitstor_cluster_nodes_offline_total`          | Total number of MinIO nodes offline.                                                                                |
| `uitstor_cluster_nodes_online_total`           | Total number of MinIO nodes online.                                                                                 |
| `uitstor_cluster_ilm_transitioned_bytes`       | Total bytes transitioned to a tier                                                                                  |
| `uitstor_cluster_ilm_transitioned_objects`     | Total number of objects transitioned to a tier                                                                      |
| `uitstor_cluster_ilm_transitioned_versions`    | Total number of versions transitioned to a tier                                                                     |
| `uitstor_heal_objects_error_total`             | Objects for which healing failed in current self healing run                                                        |
| `uitstor_heal_objects_heal_total`              | Objects healed in current self healing run                                                                          |
| `uitstor_heal_objects_total`                   | Objects scanned in current self healing run                                                                         |
| `uitstor_heal_time_last_activity_nano_seconds` | Time elapsed (in nano seconds) since last self healing activity. This is set to -1 until initial self heal activity |
| `uitstor_inter_node_traffic_received_bytes`    | Total number of bytes received from other peer nodes.                                                               |
| `uitstor_inter_node_traffic_sent_bytes`        | Total number of bytes sent to the other peer nodes.                                                                 |
| `uitstor_node_ilm_expiry_pending_tasks`        | Current number of pending ILM expiry tasks in the queue.                                                            |
| `uitstor_node_ilm_transition_active_tasks`     | Current number of active ILM transition tasks.                                                                      |
| `uitstor_node_ilm_transition_pending_tasks`    | Current number of pending ILM transition tasks in the queue.                                                        |
| `uitstor_node_disk_free_bytes`                 | Total storage available on a disk.                                                                                  |
| `uitstor_node_disk_total_bytes`                | Total storage on a disk.                                                                                            |
| `uitstor_node_disk_used_bytes`                 | Total storage used on a disk.                                                                                       |
| `uitstor_node_file_descriptor_limit_total`     | Limit on total number of open file descriptors for the MinIO Server process.                                        |
| `uitstor_node_file_descriptor_open_total`      | Total number of open file descriptors by the MinIO Server process.                                                  |
| `uitstor_node_io_rchar_bytes`                  | Total bytes read by the process from the underlying storage system including cache, /proc/[pid]/io rchar            |
| `uitstor_node_io_read_bytes`                   | Total bytes read by the process from the underlying storage system, /proc/[pid]/io read_bytes                       |
| `uitstor_node_io_wchar_bytes`                  | Total bytes written by the process to the underlying storage system including page cache, /proc/[pid]/io wchar      |
| `uitstor_node_io_write_bytes`                  | Total bytes written by the process to the underlying storage system, /proc/[pid]/io write_bytes                     |
| `uitstor_node_process_starttime_seconds`       | Start time for MinIO process per node, time in seconds since Unix epoc.                                             |
| `uitstor_node_process_uptime_seconds`          | Uptime for MinIO process per node in seconds.                                                                       |
| `uitstor_node_syscall_read_total`              | Total read SysCalls to the kernel. /proc/[pid]/io syscr                                                             |
| `uitstor_node_syscall_write_total`             | Total write SysCalls to the kernel. /proc/[pid]/io syscw                                                            |
| `uitstor_s3_requests_errors_total`             | Total number S3 requests with 4xx and 5xx errors                                                                    |
| `uitstor_s3_requests_4xx_errors_total`         | Total number S3 requests with 4xx errors                                                                            |
| `uitstor_s3_requests_5xx_errors_total`         | Total number S3 requests with 5xx errors                                                                            |
| `uitstor_s3_requests_inflight_total`           | Total number of S3 requests currently in flight                                                                     |
| `uitstor_s3_requests_total`                    | Total number S3 requests                                                                                            |
| `uitstor_s3_time_ttfb_seconds_distribution`    | Distribution of the time to first byte across API calls.                                                            |
| `uitstor_s3_traffic_received_bytes`            | Total number of s3 bytes received.                                                                                  |
| `uitstor_s3_traffic_sent_bytes`                | Total number of s3 bytes sent                                                                                       |
| `uitstor_software_commit_info`                 | Git commit hash for the MinIO release.                                                                              |
| `uitstor_software_version_info`                | MinIO Release tag for the server                                                                                    |
