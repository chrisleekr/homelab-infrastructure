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

    # kubectl rather than kubernetes_manifest for the Gateway API and Istio objects: those CRDs are
    # installed by the istio-gateway module, and kubernetes_manifest needs the type to exist at plan
    # time, which it does not on a first apply.
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
