
variable "prometheus_namespace" {
  description = "The namespace for the prometheus"
  type        = string
  default     = "monitoring"
}

variable "global_ingress_enable_tls" {
  description = "Enable TLS for the ingress"
  type        = bool
  default     = true
}

variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}

variable "argocd_domain" {
  description = "The domain name for the argocd"
  type        = string
  default     = "argocd.chrislee.local"
}

variable "argocd_ingress_class_name" {
  description = "The ingress class name for the argocd"
  type        = string
  default     = "nginx"
}

variable "argocd_ssh_known_hosts_base64" {
  description = "SSH known hosts for Git repositories - base64 encoded"
  type        = string
  default     = ""
}

variable "argocd_config_repositories" {
  description = "The repositories for the argocd"
  type = list(object({
    name = string
    type = string
    url  = string
    usernameSecret = object({
      key  = string
      name = string
    })
    passwordSecret = object({
      key  = string
      name = string
    })
  }))
  default = []
}

variable "auth_oauth2_proxy_host" {
  description = "The host for the oauth2 proxy"
  type        = string
  default     = "auth.chrislee.local"
}

variable "argocd_auth0_domain" {
  description = "The Auth0 domain for ArgoCD OIDC"
  type        = string
  default     = "chrislee.auth0.com"
}

variable "argocd_auth0_client_id" {
  description = "The Auth0 client ID for ArgoCD OIDC"
  type        = string
  default     = ""
}

variable "argocd_auth0_client_secret" {
  description = "The Auth0 client secret for ArgoCD OIDC"
  type        = string
  sensitive   = true
}

variable "argocd_rbac_policy_default" {
  description = "The default RBAC policy for ArgoCD"
  type        = string
  default     = "role:readonly"
}

variable "argocd_rbac_policy_csv" {
  description = "The RBAC policy for ArgoCD"
  type        = string
  default     = ""
}

variable "argocd_apps_repo_url" {
  description = "Git repo URL for the central ArgoCD apps repository. When set, creates a root Application that bootstraps ApplicationSets from the repo."
  type        = string
  default     = ""
}
