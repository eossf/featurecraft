resource "vultr_ssh_key" "default" {
  name    = "current-ssh-key"
  ssh_key = file("~/.ssh/id_rsa.pub")

  lifecycle {
    ignore_changes = [ssh_key]
  }
}

resource "vultr_instance" "current" {
  region         = local.default_region
  plan           = "vc2-4c-8gb"
  os_id          = 2284
  label          = "current-vm"
  hostname       = "current-host"
  ssh_key_ids    = [vultr_ssh_key.default.id]
  vpc_ids        = [vultr_vpc.default_vpc.id]
  reserved_ip_id = vultr_reserved_ip.default.id
}

resource "vultr_reserved_ip" "default" {
  region  = local.default_region
  ip_type = "v4"
}