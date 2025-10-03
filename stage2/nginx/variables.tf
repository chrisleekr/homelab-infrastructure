variable "nginx_service_loadbalancer_ip" {
  description = "The IP address of the loadbalancer ip."
  type        = string
  default     = ""
}

variable "nginx_client_max_body_size" {
  description = "The maximum body size for nginx."
  type        = string
  default     = "10M"
}

variable "nginx_client_body_buffer_size" {
  description = "The client body buffer size for nginx."
  type        = string
  default     = "10M"
}

variable "wireguard_port" {
  description = "The port for the wireguard"
  type        = string
  default     = "51820"
}
