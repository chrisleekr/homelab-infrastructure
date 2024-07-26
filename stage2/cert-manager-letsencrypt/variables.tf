variable "cert_manager_acme_email" {
  description = "The email address to register certificates requested from Let's Encrypt."
  type        = string
  default     = ""
}

variable "cert_manager_ingress_class" {
  description = "IngressClass resource for cert-manager."
  type        = string
  default     = "nginx"
}

variable "cert_manager_host_alias_ip" {
  description = "The IP address of the host alias."
  type        = string
  default     = ""
}

variable "cert_manager_host_alias_hostnames" {
  description = "The hostnames of the host alias comma separated. i.e. remote1.local,remote2.local"
  type        = string
  default     = ""
}
