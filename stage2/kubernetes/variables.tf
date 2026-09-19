variable "kubernetes_cluster_type" {
  description = "The type of the kubernetes cluster. i.e. kubeadm, k3s"
  type        = string
  default     = "kubeadm"
}

variable "kubernetes_override_domains" {
  description = "The list of domains to be added to the CoreDNS configuration. Space delimiter. i.e. gitlab.chrislee.local registry.chrislee.local minio.chrislee.local"
  type        = string
  default     = ""
}


variable "kubernetes_override_ip" {
  description = "The IP address of the host alias."
  type        = string
  default     = "192.168.1.100"
}

variable "kubernetes_gateway_domains" {
  description = "Space-delimited hostnames resolved in-cluster to the Istio gateway Service instead of the LAN address."
  type        = string
  default     = ""
}

variable "kubernetes_gateway_service_fqdn" {
  description = "In-cluster FQDN of the Service Istio auto-provisions for the shared Gateway. Pods resolve migrated hostnames to this name, so no ClusterIP is pinned."
  type        = string
  default     = "public-istio.istio-ingress.svc.cluster.local"
}
