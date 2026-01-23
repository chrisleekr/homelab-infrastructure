terraform {
  # Migrated from deprecated backend "remote" to cloud block
  # Reference: https://developer.hashicorp.com/terraform/language/backend/remote
  cloud {
    hostname     = "app.terraform.io"
    organization = "chrisleekr"

    workspaces {
      # Using tags instead of prefix for better workspace management
      # Existing workspaces with "homelab-" prefix will need to be tagged
      tags = ["homelab"]
    }
  }
}
