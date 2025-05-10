
resource "null_resource" "install_ansible" {

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y software-properties-common",
      "apt-add-repository --yes --update ppa:ansible/ansible",
      "apt-get install -y ansible"
    ]
  }

  depends_on = [vultr_instance.current]
}
