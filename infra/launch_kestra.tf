resource "null_resource" "launch_kestra" {
  depends_on = [null_resource.install_docker_with_ansible, local_file.application_yaml]

  provisioner "file" {
    source      = local_file.application_yaml.filename
    destination = "/root/application.yaml"

    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "docker run --pull=always --rm -d -p 8080:8080 --user=root -v /root/application.yaml:/etc/config/application.yaml -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp kestra/kestra:latest server standalone --config /etc/config/application.yaml"
    ]

    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}