# Provider requirements for the Istio gateway module.
#
# kubectl rather than kubernetes_manifest for every Gateway API object: the Gateway API CRDs are
# installed by this same module, and kubernetes_manifest needs a resource type to exist at plan
# time, which it does not on a first apply.
#
# http fetches the Gateway API objects from upstream at apply time, see gateway-api-crds.tf.
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

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
