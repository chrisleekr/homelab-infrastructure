# Provider requirements for the LiteLLM module.
#
# Helm deploys the proxy chart; Kubernetes owns the secrets and Postgres. kubectl writes the
# Gateway API and Istio objects in httproute.tf, whose CRDs are installed by the istio-gateway
# module, so kubernetes_manifest cannot be used: it needs the type to exist at plan time.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
