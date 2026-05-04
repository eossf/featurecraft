resource "null_resource" "data_setup" {

  provisioner "file" {
    source      = "${path.module}/data/workload-reference-api-1.28.pdf"
    destination = "/root/workload-reference-api-1.28.pdf"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "${path.module}/data/workload-reference-api-1.29.pdf"
    destination = "/root/workload-reference-api-1.29.pdf"
    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}