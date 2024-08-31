# https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#upgrading-an-existing-release-to-a-new-major-version


locals {
  prometheus_crds = [
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml",
    "kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml"
  ]
}

resource "null_resource" "prometheus_crd" {
  triggers = {
    prometheus_crd_urls = join(",", local.prometheus_crds)
    # always_run = "${timestamp()}"
  }

  # Should apply the CRDs in order; otherwise, timeout errors may occur.
  provisioner "local-exec" {
    command = local.prometheus_crds[0]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[1]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[2]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[3]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[4]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[5]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[6]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[7]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[8]
  }

  provisioner "local-exec" {
    command = local.prometheus_crds[9]
  }
}
