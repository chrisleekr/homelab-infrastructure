# https://longhorn.io/docs/archives/1.1.1/snapshots-and-backups/csi-snapshot-support/enable-csi-snapshot-support/

locals {
  crds = [
    "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml",
    "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml",
    "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml"
  ]
}

data "http" "crd" {
  count = length(local.crds)
  url   = local.crds[count.index]
}


resource "kubectl_manifest" "crd" {
  count = length(local.crds)

  yaml_body = data.http.crd[count.index].body
}
