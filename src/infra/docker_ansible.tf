resource "null_resource" "install_docker_with_ansible" {
  depends_on = [null_resource.install_ansible]

  provisioner "file" {
    source      = "install_docker.yaml"
    destination = "/root/install_docker.yaml"

    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i 'localhost,' -c local /root/install_docker.yaml"
    ]

    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}