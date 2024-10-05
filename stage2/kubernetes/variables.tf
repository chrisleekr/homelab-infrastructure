variable "kubernetes_cluster_type" {
  description = "The type of the kubernetes cluster. i.e. kubeadm, k3s"
  type        = string
  default     = "kubeadm"
}

variable "kubernetes_override_domains" {
  description = "The list of domains to be added to the CoreDNS configuration. Space delimiter. i.e. gitlab.chrislee.local registry.chrislee.local minio.chrislee.local"
  type        = string
  default     = "gitlab.chrislee.local registry.chrislee.local minio.chrislee.local"
}


variable "kubernetes_override_ip" {
  description = "The IP address of the host alias."
  type        = string
  default     = "192.168.1.100"
}
