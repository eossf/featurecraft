resource "vultr_ssh_key" "default" {
  name    = "current-ssh-key"
  ssh_key = file("~/.ssh/id_rsa.pub")
}

resource "vultr_instance" "current" {
  region      = "ewr"
  plan        = "vc2-2c-8gb"
  os_id       = 215
  label       = "current-vm"
  hostname    = "current-host"
  ssh_key_ids = [vultr_ssh_key.default.id]
}

