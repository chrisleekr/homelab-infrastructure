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

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.3"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.3"
    }
  }
}
