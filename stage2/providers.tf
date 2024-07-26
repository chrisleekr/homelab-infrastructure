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

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.4"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
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

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}
