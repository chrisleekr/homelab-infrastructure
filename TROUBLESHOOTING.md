# Troubleshooting

This document covers common issues and their solutions.

## Table of Contents

- [Development Environment](#development-environment)
- [Stage 1: Ansible](#stage-1-ansible)
- [Stage 2: Terraform](#stage-2-terraform)
- [Architecture Compatibility](#architecture-compatibility)

## Development Environment

### Running pre-commit for all files

```bash
task precommit
```

### SSH passphrase

If you need to add an SSH passphrase, use ssh-add:

```bash
eval "$(ssh-agent)"
ssh-add
```

This process is added to the `.bashrc` file and automatically executes when you launch the Docker container.

## Stage 1: Ansible

### SSH Connection Issues

If Ansible fails to connect to the target server:

1. Verify SSH connectivity manually:

   ```bash
   ssh -p <port> <user>@<host>
   ```

2. Ensure the SSH key is added:

   ```bash
   eval "$(ssh-agent)"
   ssh-add
   ```

3. Check that the SSH port in `.env` matches the server configuration.

## Stage 2: Terraform

### Error with `no matches for kind "ServiceMonitor"`

```text
Error: unable to build kubernetes objects from release manifest: resource mapping not found for name: "nginx-ingress-nginx-controller" namespace: "nginx" from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

This error occurs when Prometheus CRDs are not installed.

**Solution:**

1. Go to `stage2/kubernetes/prometheus-crd.tf`
2. Uncomment the following line:

   ```text
   # always_run          = "${timestamp()}"
   ```

3. Re-run: `terraform apply`

### GitLab registry storage full

```bash
$ kubectl logs -ngitlab gitlab-registry-<pod-id>
{"error":"XMinioStorageFull: Storage backend has reached its minimum free drive threshold..."}
```

**Solution:**

Expand MinIO PVCs:

```bash
kubectl edit -nminio-tenant pvc data0-minio-tenant-pool-0-0
kubectl edit -nminio-tenant pvc data1-minio-tenant-pool-0-0
kubectl edit -nminio-tenant pvc data2-minio-tenant-pool-0-0
kubectl edit -nminio-tenant pvc data3-minio-tenant-pool-0-0
```

### Terraform state lock

If Terraform reports a state lock error:

```bash
terraform force-unlock <lock-id>
```

**Note:** Only use this if you're certain no other process is running Terraform.

### Docker push to GitLab registry fails with 500 Internal Server Error

**Symptoms:**

```text
error: failed to copy: unexpected status from PUT request to https://registry.example.com/v2/.../blobs/uploads/...: 500 Internal Server Error
unknown: unknown error
```

**Registry logs show:**

```text
api error InvalidArgument: Invalid arguments provided for gitlab-registry-storage/...: (checksum missing, want "CRC64NVME", got "")
```

**Cause:**

This occurs when using MinIO with the GitLab registry's `s3_v2` driver. Recent MinIO versions require CRC64NVME checksums for `UploadPartCopy` operations, but the AWS SDK v2 used by the s3_v2 driver doesn't send them.

**Solution:**

Add `checksum_disabled: true` to the registry storage configuration in `stage2/gitlab-platform/templates/registry-storage.tftpl`:

```yaml
s3_v2:
  region: us-east-1
  bucket: gitlab-registry-storage
  regionendpoint: "${minio_endpoint}"
  forcepathstyle: true
  accesskey: ${minio_access_key}
  secretkey: ${minio_secret_key}
  chunksize: 26214400
  checksum_disabled: true  # Required for MinIO compatibility
```

**Reference:** [GitLab Container Registry Administration](https://docs.gitlab.com/ee/administration/packages/container_registry.html)

## Architecture Compatibility

### GitLab AMD64 Only

GitLab (`registry.gitlab.com/gitlab-org/build/cng/kubectl`) does not support ARM64 yet.

- GitLab is automatically skipped on ARM64 architectures
- Other services support both AMD64 and ARM64

### Checking Current Architecture

The architecture is set in `.env`:

```bash
host_machine_architecture=amd64    # or arm64
```

## Getting Help

If your issue is not covered here:

1. Check the [module-specific READMEs](stage2/) for detailed configuration
2. Review the [GitHub Issues](https://github.com/chrisleekr/homelab-infrastructure/issues) for similar problems
3. Open a new issue with:
   - Description of the problem
   - Steps to reproduce
   - Error messages
   - Environment details (architecture, Kubernetes version, etc.)
