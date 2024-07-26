terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.14.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.5"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }

    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.3"
    }

  }
}
