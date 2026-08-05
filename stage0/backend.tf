terraform {
  # Tag-based, not a fixed name, mirroring stage2/backend.tf. One workspace holds every
  # cloud account; accounts are selected in code, not by terraform.workspace.
  cloud {
    hostname     = "app.terraform.io"
    organization = "chrisleekr"

    workspaces {
      tags = ["homelab", "stage0"]
    }
  }
}
