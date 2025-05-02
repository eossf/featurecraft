# main.tf

variable "vultr_api_key" {
  description = "API key for Vultr provider"
  type        = string
  sensitive   = true
}

variable "kestra_username" {
  type        = string
  description = "Kestra basic auth username"
  default     = "stephane.metairie@gmail.com"
}

variable "kestra_password" {
  type        = string
  description = "Kestra basic auth password"
  default     = "kestra"
}

provider "vultr" {
  api_key = var.vultr_api_key
}

provider "tls" {}

provider "local" {}

provider "null" {}

resource "tls_private_key" "instance_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "instance_ssh_private_key" {
  content  = tls_private_key.instance_ssh_key.private_key_pem
  filename = "${path.module}/instance_ssh_key"
}

resource "vultr_ssh_key" "default" {
  name    = "current-ssh-key"
  ssh_key = file("~/.ssh/id_rsa.pub")

  lifecycle {
    ignore_changes = [ssh_key]
  }
}

resource "vultr_vpc" "default_vpc" {
  description    = "private vpc"
  region         = "cdg"
  v4_subnet      = "10.0.0.0"
  v4_subnet_mask = 24
}

resource "vultr_reserved_ip" "default" {
  region  = "cdg"
  ip_type = "v4"
}

resource "vultr_instance" "current" {
  region         = "cdg"
  plan           = "vc2-4c-8gb"
  os_id          = 2284 # Ubuntu 22.04 x64
  label          = "current"
  ssh_key_ids    = [vultr_ssh_key.default.id]
  vpc_ids        = [vultr_vpc.default_vpc.id]
  reserved_ip_id = vultr_reserved_ip.default.id
}

resource "null_resource" "install_ansible" {
  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update -y",
      "apt-get install -y software-properties-common",
      "add-apt-repository --yes --update ppa:ansible/ansible",
      "apt-get install -y ansible"
    ]
  }
}

resource "null_resource" "install_docker_with_ansible" {
  depends_on = [null_resource.install_ansible]

  provisioner "file" {
    source      = "install_docker.yml"
    destination = "/root/install_docker.yml"

    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i 'localhost,' -c local /root/install_docker.yml"
    ]

    connection {
      type        = "ssh"
      host        = vultr_instance.current.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "null_resource" "install_docker_compose" {
  depends_on = [null_resource.install_docker_with_ansible]

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
        private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "curl -L \"https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64\" -o /usr/local/bin/docker-compose",
      "chmod +x /usr/local/bin/docker-compose",
      "ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose"
    ]
  }
}

data "template_file" "compose" {
  template = <<-EOT
volumes:
  postgres-data:
    driver: local
  kestra-data:
    driver: local

services:
  postgres:
    image: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: kestra
      POSTGRES_USER: "${var.kestra_username}"
      POSTGRES_PASSWORD: "${var.kestra_password}"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d ${var.kestra_username} -U ${var.kestra_username}"]
      interval: 30s
      timeout: 10s
      retries: 10

  kestra:
    image: kestra/kestra:latest
    pull_policy: always
    user: "root"
    command: server standalone
    volumes:
      - kestra-data:/app/storage
      - /var/run/docker.sock:/var/run/docker.sock
      - /tmp/kestra-wd:/tmp/kestra-wd
    environment:
      KESTRA_CONFIGURATION: |
        datasources:
          postgres:
            url: jdbc:postgresql://postgres:5432/kestra
            driverClassName: org.postgresql.Driver
            username: "${var.kestra_username}"
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
                path: /tmp/kestra-wd/tmp
            url: http://localhost:8080/
    ports:
      - "8080:8080"
      - "8081:8081"
    depends_on:
      postgres:
        condition: service_started
EOT

  vars = {
    kestra_username = var.kestra_username
    kestra_password = var.kestra_password
  }
}

resource "local_file" "compose" {
  content  = data.template_file.compose.rendered
  filename = "${path.module}/docker-compose.yaml"
}

resource "null_resource" "upload_compose_file" {
  depends_on = [local_file.compose]

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "file" {
    source      = local_file.compose.filename
    destination = "/root/docker-compose.yaml"
  }
}

resource "null_resource" "start_docker_compose" {
  depends_on = [null_resource.upload_compose_file]

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "docker compose up -f /root/docker-compose.yaml -d"
    ]
  }
}