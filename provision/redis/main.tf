provider "vault" {
  # configure it using environment variables
  # VAULT_ADDR - target Vault address
  # VAULT_TOKEN - auth token
}

ephemeral "vault_kv_secret_v2" "proxmox_creds" {
  mount = "infra-secrets"
  name  = "proxmox/creds"
}

locals {
  vault_proxmox = ephemeral.vault_kv_secret_v2.proxmox_creds.data
  proxmox_user  = local.vault_proxmox.username
  proxmox_pass  = local.vault_proxmox.password
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true

  username = local.proxmox_user
  password = local.proxmox_pass
}


module "redis" {
  source = "../../modules/pve_pool"

  name        = "redis-ha"
  vms_name    = "redis-srv"
  description = "Redis HA VMs pool"
  tags        = ["redis", "production"]
  start_id    = 107

  agent_on = true
  node     = "pve"
  size     = 3

  auth = {
    user     = "user"
    pass     = "$5$AGuU1Ws8C18XnI1r$s.5V.LE6HS/242LDQKPcROjfRkH1cpHNnDG7v/T/EkD"
    ssh_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0yO9RABzbP4OhuNYjjAo+xtwyVUHsg9sbIQxhYIFMp"]
  }

  resources = {
    cpu    = 8
    memory = 8
    hugepg = false
  }

  base = {
    os      = "alpine"
    version = "3.21.0"
    arch    = "x86_64"
  }

  network = {
    cidr   = "192.168.0.0/24"
    domain = "cluster.local"
    dns    = ["8.8.8.8"]


    acls = [
      { cidr = "0.0.0.0", ports = "22,80,443", policy = "accept", proto = "tcp", },
    ]
  }

  disks = {
    root      = { storage = "SSD", size = 8 },
    cloudinit = { storage = "SSD" },
    other = [
      { storage = "SSD", size = 32, },
    ],
  }
}
