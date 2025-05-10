terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.26.0"
    }
    tls   = { source = "hashicorp/tls" }
    null  = { source = "hashicorp/null" }
    local = { source = "hashicorp/local" }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

variable "vultr_api_key" {
  description = "Vultr API Key"
  type        = string
  sensitive   = true
}

variable "kestra_username" {
  description = "Kestra Basic Auth Username"
  type        = string
  default     = "stephane.metairie@gmail.com"
}

variable "kestra_password" {
  description = "Kestra Basic Auth Password"
  type        = string
  sensitive   = true
}

resource "vultr_ssh_key" "kestra" {
  name    = "kestra-ssh-key"
  ssh_key = file("~/.ssh/id_rsa.pub")

  lifecycle {
    ignore_changes = [ssh_key]
  }
}

resource "vultr_vpc" "kestra" {
  description    = "kestra VPC"
  region         = "cdg"
  v4_subnet      = "10.0.0.0"
  v4_subnet_mask = 24
}

resource "vultr_reserved_ip" "kestra" {
  region  = "cdg"
  ip_type = "v4"
  label   = "kestra-ip"
}

resource "vultr_instance" "kestra" {
  region         = "cdg"
  plan           = "vc2-4c-8gb"
  os_id          = 2284
  label          = "kestra"
  ssh_key_ids    = [vultr_ssh_key.kestra.id]
  vpc_ids        = [vultr_vpc.kestra.id]
  reserved_ip_id = vultr_reserved_ip.kestra.id
  hostname       = "kestra-server"
}

resource "null_resource" "install_ansible" {
  depends_on = [vultr_instance.kestra]

  connection {
    type        = "ssh"
    host        = vultr_instance.kestra.main_ip
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

data "template_file" "install_docker" {
  template = <<EOT
---
- hosts: localhost
  become: true
  tasks:
    - name: Install Docker
      shell: curl -fsSL https://get.docker.com | sh
EOT
}

resource "local_file" "install_docker_playbook" {
  content  = data.template_file.install_docker.rendered
  filename = "${path.module}/install_docker.yaml"
}

resource "null_resource" "upload_docker_playbook" {
  depends_on = [local_file.install_docker_playbook]

  connection {
    type        = "ssh"
    host        = vultr_instance.kestra.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    source      = local_file.install_docker_playbook.filename
    destination = "/root/install_docker.yaml"
  }
}

resource "null_resource" "install_docker_with_ansible" {
  depends_on = [null_resource.upload_docker_playbook]

  connection {
    type        = "ssh"
    host        = vultr_instance.kestra.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "ansible-playbook /root/install_docker.yaml"
    ]
  }
}

data "template_file" "docker_compose" {
  template = <<EOT
version: '3'

services:
  postgres:
    image: postgres:14
    container_name: postgres
    restart: always
    environment:
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: kestra
      POSTGRES_DB: kestra
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kestra"]
      interval: 10s
      timeout: 5s
      retries: 5

  kestra:
    image: kestra/kestra:latest
    container_name: kestra
    restart: always
    ports:
      - "8080:8080"
    environment:
      KESTRA_DATABASE_TYPE: postgres
      KESTRA_DATABASE_URL: jdbc:postgresql://postgres:5432/kestra
      KESTRA_DATABASE_USERNAME: kestra
      KESTRA_DATABASE_PASSWORD: kestra
      KESTRA_SERVER_BASIC_AUTH_USERNAME: ${var.kestra_username}
      KESTRA_SERVER_BASIC_AUTH_PASSWORD: ${var.kestra_password}
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  postgres-data:
EOT
}

resource "local_file" "compose" {
  content  = data.template_file.docker_compose.rendered
  filename = "docker-compose.yaml"
}

resource "null_resource" "launch_kestra" {
  depends_on = [null_resource.install_docker_with_ansible, local_file.compose]

  provisioner "file" {
    source      = local_file.compose.filename
    destination = "/root/docker-compose.yaml"

    connection {
      type        = "ssh"
      host        = vultr_instance.kestra.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "docker compose up -d --force-recreate --remove-orphans",
    ]

    connection {
      type        = "ssh"
      host        = vultr_instance.kestra.main_ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}
