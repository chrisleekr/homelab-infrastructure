# Provider requirements for the OmniRoute module.
# Helm deploys the gateway chart; Kubernetes owns the namespace and auth Secret; kubectl applies the
# Gateway API and Istio objects, whose CRDs are not in the Kubernetes provider's schema.

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
