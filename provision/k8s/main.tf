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

provider "helm" {
  kubernetes = {
    config_path = "/tmp/k8s_admin.conf"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "tls_private_key" "cert" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "cert" {
  private_key_pem       = tls_private_key.cert.private_key_pem
  validity_period_hours = 87600

  allowed_uses = [
    "any_extended",
    "client_auth",
    "server_auth",
    "timestamping",
    "crl_signing",
    "ocsp_signing",
    "cert_signing",
  ]

  subject {
    common_name = "Kubernetes"
  }

  is_ca_certificate = true
}

module "k8s" {
  source = "../../modules/pve_k8s"

  network = {
    cidr   = "192.168.0.0/24"
    dns    = "8.8.8.8"
    domain = "cluster.local"
  }

  kubeconfig_path = "/tmp/k8s_admin.conf"

  start_id = 100
  node     = "pve"

  auth = {
    user = "user"
    pass = "$5$C.6CsFKu0G6.tRIc$ciI0ED17SzFKA10agSTe87SnfLQ32q9iu8sq3ivt0R9"
    ssh_keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0yO9RABzbP4OhuNYjjAo+xtwyVUHsg9sbIQxhYIFMp space@space"
    ]
  }

  groups = {
    control = {
      size       = 2
      node_name  = "control-node"
      is_control = true
      reserved   = 2

      resources = {
        cpu    = 4
        memory = 8
      }
    }
    worker = {
      size      = 2
      node_name = "worker-node"
      reserved  = 2

      resources = {
        cpu    = 4
        memory = 8
      }
    }
  }

  cert = {
    ca  = tls_self_signed_cert.cert.cert_pem
    key = tls_private_key.cert.private_key_pem
  }
}
