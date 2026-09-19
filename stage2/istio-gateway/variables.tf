# Input variables for the Istio gateway module.
#
# The module installs the control plane, the Gateway API CRDs and one Gateway. It carries no
# traffic until a Cloudflare Tunnel published application route points a hostname at the gateway
# Service, so it can be applied before any hostname points at it.

variable "istio_gateway_version" {
  description = "Istio version for both the base and istiod charts"
  type        = string
  default     = "1.31.0"
}

variable "istio_gateway_chart_repository" {
  description = "Istio Helm chart repository. The storage.googleapis.com mirror stops at 1.30.4, so 1.31 and later must come from blob.istio.io"
  type        = string
  default     = "https://blob.istio.io/istio-release/charts"
}

variable "istio_gateway_api_version" {
  description = "Gateway API release tag, standard channel. The module fetches five CRDs from it plus the safe-upgrades ValidatingAdmissionPolicy, which rejects experimental CRDs and releases older than v1.5. Changing this requires refreshing the checksums in gateway-api-crds.tf"
  type        = string
  default     = "v1.6.2"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.istio_gateway_api_version))
    error_message = "Must be a released bundle version such as v1.6.2"
  }
}

variable "istio_gateway_control_plane_namespace" {
  description = "Namespace for istiod. Also the Istio root namespace, where mesh-wide config is read from"
  type        = string
  default     = "istio-system"
}

variable "istio_gateway_namespace" {
  description = "Namespace holding the Gateway, its auto-provisioned Deployment and Service, and the per-host TLS Secrets"
  type        = string
  default     = "istio-ingress"
}

variable "istio_gateway_name" {
  description = "Gateway resource name. Istio names the generated Deployment and Service <name>-istio, which is the origin a Cloudflare Tunnel route points at"
  type        = string
  default     = "public"
}

# Requests come from measured usage with 18 hostnames configured: istiod 95Mi and the gateway proxy
# 138Mi. The chart default of 500m/2048Mi is sized for a full mesh and would reserve a quarter of
# this node's memory for nothing.
#
# The proxy request sits above its measured steady state on purpose. The kubelet ranks eviction by
# usage relative to request, so a pod permanently above its own request is reclaimed first, and this
# one is the ingress path for every public hostname.
variable "istio_gateway_istiod_requests" {
  description = "Resource requests for istiod"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "128Mi"
  }
}

variable "istio_gateway_proxy_requests" {
  description = "Resource requests for the gateway proxy container"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "50m"
    memory = "160Mi"
  }
}

variable "istio_gateway_num_trusted_proxies" {
  description = "Number of trusted proxy hops in front of the gateway, used to pick the client address out of X-Forwarded-For. 1 matches Cloudflare Tunnel as the only hop. Raising it without a matching hop lets a client forge its own address"
  type        = number
  default     = 1

  validation {
    condition     = var.istio_gateway_num_trusted_proxies >= 0
    error_message = "Must be zero or greater"
  }
}

variable "istio_gateway_ext_authz_service" {
  description = "Cluster DNS name of the oauth2-proxy Service used as the ext_authz provider for protected hosts"
  type        = string
  default     = "oauth2-proxy.auth.svc.cluster.local"
}

variable "istio_gateway_ext_authz_port" {
  description = "Port of the oauth2-proxy Service"
  type        = number
  default     = 80
}

variable "istio_gateway_acme_email" {
  description = "Contact address for the ACME account used by letsencrypt-gateway."
  type        = string
  default     = ""
}

variable "istio_gateway_acme_server" {
  description = "ACME directory URL. Point at the staging directory to rehearse a host cutover without burning rate limits"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "istio_gateway_acme_cloudflare_secret" {
  description = "Name of the Secret in cert-manager's namespace holding the Cloudflare API token, created by the cert-manager module and read by the DNS-01 solver"
  type        = string
  default     = "cloudflare-api-token"
}
