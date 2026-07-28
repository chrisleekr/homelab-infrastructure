locals {
  gitlab_namespace = kubernetes_namespace_v1.gitlab.metadata[0].name

  # CNPG and the Valkey chart both derive their Service names from a name declared elsewhere in
  # this module. Deriving the hostnames from those same names keeps the resource definitions and
  # the GitLab Helm values from drifting apart: a wrong Service name fails at connect time, well
  # after apply reports success.
  postgres_cluster_name = "gitlab-pg"
  # CNPG publishes <cluster>-rw, always routed to the current primary.
  postgres_rw_host = "${local.postgres_cluster_name}-rw.${local.gitlab_namespace}.svc.cluster.local"

  # The release name contains the chart name, so the chart fullname collapses to it.
  valkey_release_name = "gitlab-valkey"
  valkey_host         = "${local.valkey_release_name}.${local.gitlab_namespace}.svc.cluster.local"
}
