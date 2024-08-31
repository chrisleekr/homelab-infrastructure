terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.4"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.3"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
  }
}
