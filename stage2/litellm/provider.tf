# Provider requirements for the LiteLLM module.
# Helm deploys the proxy chart; Kubernetes owns the secrets, Postgres, and ingresses.

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
  }
}
