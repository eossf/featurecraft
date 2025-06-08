resource "null_resource" "launch" {
  depends_on = [null_resource.install_docker_with_ansible, local_file.compose]

  provisioner "file" {
    source      = local_file.compose.filename
    destination = "/root/docker-compose.yaml"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "${path.module}/init-data.sh"
    destination = "/root/init-data.sh"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "${path.module}/nginx.conf"
    destination = "/root/nginx.conf"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "null_resource" "push_tls_certs" {
  triggers = {
    domain_cert_hash = filesha256("${path.module}/certs/domain.cert.pem")
    private_key_hash = filesha256("${path.module}/certs/private.key.pem")
  }

  provisioner "file" {
    source      = "${path.module}/certs/domain.cert.pem"
    destination = "/root/domain.cert.pem"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "${path.module}/certs/private.key.pem"
    destination = "/root/private.key.pem"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}