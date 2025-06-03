# https://longhorn.io/docs/archives/1.1.1/snapshots-and-backups/csi-snapshot-support/enable-csi-snapshot-support/

locals {
  longhorn_crds = [
    "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml",
    "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml",
    "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml"
  ]
}

data "http" "longhorn_crd" {
  count = length(local.longhorn_crds)
  url   = local.longhorn_crds[count.index]
}


resource "kubectl_manifest" "longhorn_crd" {
  count = length(local.longhorn_crds)

  yaml_body = data.http.longhorn_crd[count.index].body
}
