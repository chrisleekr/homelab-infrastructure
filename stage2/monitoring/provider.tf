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

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
