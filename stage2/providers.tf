terraform {
  required_version = ">= 1.5.0"

  # Provider version constraints use pessimistic operator (~>) per HashiCorp best practices:
  # https://developer.hashicorp.com/terraform/language/expressions/version-constraints#best-practices
  # This allows minor/patch updates but prevents breaking major version changes.
  # Updated to latest versions as of January 2026.
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}
