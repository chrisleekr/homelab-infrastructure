
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
  description = "The fallback RBAC role for non-admin ArgoCD identities; empty requires explicit policy grants"
  type        = string
  default     = ""
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

  validation {
    condition     = var.argocd_apps_repo_url == "" || can(regex("^(https?://|git@|ssh://)", var.argocd_apps_repo_url))
    error_message = "argocd_apps_repo_url must be empty or a valid Git URL (https://, http://, git@, or ssh://)"
  }
}

variable "argocd_notifications_slack_token" {
  description = "Slack bot token used by the notifications controller. Empty leaves Slack notifications off."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.argocd_notifications_slack_token == "" || can(regex("^xoxb-\\S+$", var.argocd_notifications_slack_token))
    error_message = "Give an empty string or a non-rotating Slack bot token starting 'xoxb-' with no surrounding whitespace. Rotating 'xoxe.xoxb-' tokens are not supported because the controller holds a single static token it cannot refresh."
  }
}

# The trigger names are not free text: each one must have a matching trigger and template definition
# in templates/argocd-values.tftpl, so the validation pins them to the catalog that file ships.
variable "argocd_notifications_slack_subscriptions" {
  description = "Default Slack routing applied to every Application. Each entry sends its triggers to its channels, optionally narrowed to Applications matching a label selector."
  type = list(object({
    triggers = list(string)
    channels = list(string)
    selector = optional(string, "")
  }))
  default = []

  validation {
    condition     = alltrue([for s in var.argocd_notifications_slack_subscriptions : length(s.triggers) > 0 && length(s.channels) > 0])
    error_message = "Every subscription needs at least one trigger and at least one channel."
  }

  validation {
    condition     = alltrue([for s in var.argocd_notifications_slack_subscriptions : alltrue([for c in s.channels : can(regex("^[^#\\pZ\\pC][^\\pZ\\pC]*$", c))])])
    error_message = "Give channel names with no whitespace and no leading '#'. The module prepends 'slack:', so '#alerts' would render as the recipient 'slack:#alerts'."
  }

  validation {
    condition     = alltrue([for s in var.argocd_notifications_slack_subscriptions : alltrue([for t in s.triggers : contains(["on-deployed", "on-sync-failed", "on-health-degraded"], t)])])
    error_message = "Triggers must come from the catalog in templates/argocd-values.tftpl: on-deployed, on-sync-failed, on-health-degraded."
  }
}
