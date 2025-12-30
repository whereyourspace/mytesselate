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

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

locals {
  vms = {
    mon = {
      size = 3

      resources = {
        memory = 5
      }

      disks = {
        other = [
          { storage = "SSD", size = 100, ssd = true },
          { storage = "SSD", size = 8, ssd = true },
        ]
      }

      pub_keys = tls_private_key.ssh.public_key_openssh[*]

      acls = [
        { cidr = "0.0.0.0/0", ports = "0:65535", policy = "accept", proto = "tcp" }
      ]
    }

    mgr = {
      size = 1

      resources = {
        cpu = 2
      }

      disks = {
        other = [{ storage = "SSD", size = 8, ssd = true }]
      }

      user_cloudinit = {
        content = templatefile("${path.module}/cloud-init/copy-ssh.yml.j2", {
          ssh_key     = tls_private_key.ssh.private_key_openssh
          ssh_key_pub = tls_private_key.ssh.public_key_openssh
        })
      }

      acls = [
        { cidr = "0.0.0.0/0", ports = "0:65535", policy = "accept", proto = "tcp" }
      ]
    }

    osd = {
      size = 1

      resources = {
        cpu    = 4
        memory = 4
      }

      disks = {
        other = [
          { storage = "SSD", size = 640, ssd = true },
          { storage = "HDD", size = 3072 },
        ]
      }

      pub_keys = tls_private_key.ssh.public_key_openssh[*]

      acls = [
        { cidr = "0.0.0.0/0", ports = "0:65535", policy = "accept", proto = "tcp" }
      ]
    }
  }

  start_id = 121
  vms_size = [for name, props in local.vms : lookup(props, "reserve", 5) > props.size ? lookup(props, "reserve", 5) : props.size]
  vms_start_id = {
    for ind, key in keys(local.vms) :
    key => local.start_id + sum(ind > 0 ? slice(local.vms_size, 0, ind) : [0])
  }
}

module "ceph" {
  source = "../../modules/pve_pool"

  for_each    = local.vms
  name        = "Ceph-${upper(each.key)}"
  vms_name    = "ceph-${each.key}-srv"
  description = "Ceph ${upper(each.key)} VMs pool"
  tags        = ["ceph", "ceph-${each.key}", "production"]
  start_id    = local.vms_start_id[each.key]

  agent_on = true
  node     = "pve"
  size     = each.value.size

  auth = {
    user     = "user"
    pass     = "$5$AGuU1Ws8C18XnI1r$s.5V.LE6HS/242LDQKPcROjfRkH1cpHNnDG7v/T/EkD"
    ssh_keys = concat(["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0yO9RABzbP4OhuNYjjAo+xtwyVUHsg9sbIQxhYIFMp"], lookup(each.value, "pub_keys", []))
  }

  resources = merge({
    cpu    = 2
    memory = 4
    hugepg = false
  }, lookup(each.value, "resources", {}))

  base = {
    os      = "ubuntu"
    version = "noble"
    arch    = "x86_64"
  }

  user_cloudinit = lookup(each.value, "user_cloudinit", null)

  network = {
    cidr   = "192.168.0.0/24"
    dns    = ["8.8.8.8"]
    domain = "local"

    acls = lookup(each.value, "acls", [])
  }

  disks = merge({
    root      = { storage = "SSD", size = 8 }
    cloudinit = { storage = "SSD" }
    other     = [{ storage = "SSD", size = 8, ssd = true }]
  }, lookup(each.value, "disks", {}))
}
