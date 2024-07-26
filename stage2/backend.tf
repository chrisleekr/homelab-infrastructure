terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "chrisleekr"

    workspaces {
      prefix = "homelab-"
    }
  }
}
