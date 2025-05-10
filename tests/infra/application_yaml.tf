data "template_file" "application_yaml" {
  template = <<-EOT
    services:
      datasources:
        postgres:
          url: jdbc:postgresql://postgres:5432/kestra
          driverClassName: org.postgresql.Driver
          username: kestra
          password: "${var.kestra_password}"
      kestra:
        server:
          basicAuth:
            enabled: false
            username: "${var.kestra_username}"
            password: "${var.kestra_password}"
        repository:
          type: postgres
        storage:
          type: local
          local:
            basePath: "/app/storage"
        queue:
          type: postgres
        tasks:
          tmpDir:
            path: "/tmp/kestra-wd/tmp"
        url: "http://localhost:8080/"
  EOT

  vars = {
    kestra_username = var.kestra_username
    kestra_password = var.kestra_password
  }
}

resource "local_file" "application_yaml" {
  content  = data.template_file.application_yaml.rendered
  filename = "${path.module}/application.yaml"
}