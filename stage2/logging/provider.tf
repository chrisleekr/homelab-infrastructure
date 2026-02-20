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

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
  }
}
