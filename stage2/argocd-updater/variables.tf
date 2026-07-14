variable "argocd_namespace" {
  description = "Namespace where ArgoCD (and therefore the Application CRs) live. The ImageUpdater CRs must be in the same namespace."
  type        = string
}

variable "container_registry_prefix" {
  description = "Registry host that image-updater scans. Must match the image prefix used in the Application manifests."
  type        = string
  default     = "registry.chrislee.local"
}

variable "container_registry_api_url" {
  description = "Base URL of the registry API used to list tags and read manifests"
  type        = string
  default     = "https://registry.chrislee.local"
}

variable "container_registry_credentials" {
  description = "Registry read credentials as 'username:token'. GitLab deploy token with the read_registry scope."
  type        = string
  sensitive   = true

  validation {
    # This module is only instantiated when argocd_image_updater_enable is true, so a
    # missing credential here is always a misconfiguration. Fail at plan, not at pod pull.
    condition     = can(regex("^[^:]+:[^:]+$", var.container_registry_credentials))
    error_message = "container_registry_credentials is required in 'username:token' form when ArgoCD Image Updater is enabled"
  }
}

variable "argocd_apps_git_username" {
  description = "Username for the git write-back token. For a GitLab project access token this is the token name."
  type        = string
  default     = "argocd-image-updater"
}

variable "argocd_apps_git_password" {
  description = "Git write-back token for the argocd-apps repository. GitLab project access token with the write_repository scope."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.argocd_apps_git_password) > 0
    error_message = "argocd_apps_git_password is required when ArgoCD Image Updater is enabled"
  }
}
