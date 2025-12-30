terraform {
  required_version = ">= 1.13.0"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.2.0"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.83.0"
    }
  }
}
