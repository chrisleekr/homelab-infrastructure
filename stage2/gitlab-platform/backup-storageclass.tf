# Dedicated class for the nightly backup's generic ephemeral volume.
#
# The shared `longhorn` class is reclaimPolicy: Retain, which is correct for gitaly/postgres/redis
# where an accidental PVC deletion must not destroy data. It is wrong here: a generic ephemeral
# volume's PVC is owned by its pod, so pruning yesterday's job deletes the PVC, and Retain then
# leaves the PV Released forever. That would strand one Longhorn volume, holding a full backup
# tarball, every night.
#
# Parameters mirror the `longhorn` class so the volume behaves identically apart from reclaim.
# Do not substitute the built-in `longhorn-static` class: it omits numberOfReplicas and would
# inherit the global default replica count.
resource "kubernetes_storage_class_v1" "gitlab_backup_ephemeral" {
  metadata {
    name = "longhorn-gitlab-backup-ephemeral"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }

  storage_provisioner = "driver.longhorn.io"

  # The whole point of this class. Note the provider has no ForceNew on reclaim_policy and its
  # update only patches metadata and allow_volume_expansion, so editing this in place would plan a
  # silent no-op and re-diff forever. Replace the resource instead.
  reclaim_policy = "Delete"

  # Kubernetes recommends late binding for generic ephemeral volumes: it leaves the scheduler free
  # to place the pod, and avoids provisioning a volume for a pod that never schedules.
  volume_binding_mode = "WaitForFirstConsumer"

  allow_volume_expansion = true

  parameters = {
    numberOfReplicas    = "1"
    staleReplicaTimeout = "30"
    fromBackup          = ""
    fsType              = "ext4"
    dataLocality        = "disabled"
  }
}
