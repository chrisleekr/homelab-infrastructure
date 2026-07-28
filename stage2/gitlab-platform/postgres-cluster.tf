# PostgreSQL 17 for GitLab, replacing the bundled PostgreSQL chart removed in chart 10.0.
# GitLab 19.0 sets MINIMUM_POSTGRES_VERSION = 17 (lib/gitlab/database.rb), so moving off the
# bundled 16.6 is a major-version upgrade, not just a relocation.
#
# bootstrap.initdb.import runs pg_dump against the live bundled instance over the network and
# executes only once, at bootstrap. Re-running the import requires deleting this Cluster and
# its PVC first, which is what makes a zero-downtime rehearsal against the live source possible.
resource "kubectl_manifest" "gitlab_postgres" {
  depends_on = [
    helm_release.cloudnative_pg,
    kubernetes_secret_v1.postgresql_password
  ]

  # The provider's built-in wait covers Deployment/DaemonSet/StatefulSet/APIService rollouts only,
  # so a Cluster returns as soon as the API server accepts it. Ready flips true after the import
  # finishes, which is what GitLab's migrations need. Provider default timeout is 10m; pg_dump and
  # pg_restore of both databases can outrun that.
  wait_for {
    condition {
      type   = "Ready"
      status = "True"
    }
  }

  timeouts {
    create = "45m"
  }

  yaml_body = <<-EOF
  apiVersion: postgresql.cnpg.io/v1
  kind: Cluster
  metadata:
    name: ${local.postgres_cluster_name}
    namespace: ${local.gitlab_namespace}
  spec:
    instances: 1
    # Pinned deliberately: the operator's own default is an 18.x image, above what GitLab 19.0
    # supports. "standard" is the supported variant; "system" is deprecated upstream.
    imageName: ghcr.io/cloudnative-pg/postgresql:17.10-standard-trixie
    storage:
      size: ${var.gitlab_postgres_storage_size}
      storageClass: ${var.gitlab_persistence_storage_class_name}
    monitoring:
      enablePodMonitor: true
    bootstrap:
      initdb:
        import:
          # monolith preserves database names and owners, carries role password hashes across
          # from pg_authid, and takes both databases in one pass. microservice renames the
          # database and cannot carry the registry one at all.
          type: monolith
          databases:
            - gitlabhq_production
            - registry
          roles:
            - gitlab
            - registry
          source:
            externalCluster: bundled-pg
    externalClusters:
      - name: bundled-pg
        connectionParameters:
          host: gitlab-postgresql.gitlab.svc.cluster.local
          user: postgres
          dbname: postgres
          sslmode: disable
        password:
          name: ${kubernetes_secret_v1.postgresql_password.metadata[0].name}
          key: postgresql-postgres-password
  EOF
}
