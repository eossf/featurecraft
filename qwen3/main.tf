terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.26.0"
    }
    tls   = {}
    local = {}
    null  = {}
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

variable "vultr_api_key" {
  type      = string
  sensitive = true
}

variable "kestra_username" {
  type    = string
  default = "stephane.metairie@gmail.com"
}

variable "kestra_password" {
  type      = string
  default   = "kestra"
  sensitive = true
}

resource "vultr_ssh_key" "default" {
  name    = "kestra-ssh-key"
  ssh_key = file("~/.ssh/id_rsa.pub")

  lifecycle {
    ignore_changes = [ssh_key]
  }
}

resource "vultr_vpc" "cdg" {
  description    = "private vpc"
  region         = "cdg"
  v4_subnet      = "10.0.0.0"
  v4_subnet_mask = 24
}

resource "vultr_reserved_ip" "cdg" {
  region  = "cdg"
  ip_type = "v4"
}

resource "vultr_instance" "kestra" {
  region         = "cdg"
  plan           = "vc2-4c-8gb"
  os_id          = 2284
  label          = "kestra"
  ssh_key_ids    = [vultr_ssh_key.default.id]
  vpc_ids        = [vultr_vpc.cdg.id]
  reserved_ip_id = vultr_reserved_ip.cdg.id
}

resource "null_resource" "install_ansible" {
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
      "add-apt-repository ppa:ansible/ansible -y",
      "apt-get install ansible -y"
    ]
  }
}

data "template_file" "docker_playbook" {
  template = <<EOF
---
- hosts: localhost
  tasks:
  - name: Install Docker
    shell: curl -fsSL https://get.docker.com | sh
EOF
}

resource "null_resource" "upload_docker_playbook" {
  depends_on = [null_resource.install_ansible]

  connection {
    type        = "ssh"
    host        = vultr_instance.kestra.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    content     = data.template_file.docker_playbook.rendered
    destination = "/tmp/install_docker.yaml"
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
    inline = ["ansible-playbook /tmp/install_docker.yaml"]
  }
}

data "template_file" "docker_compose" {
  template = <<EOF
version: '3'
services:
  postgres:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  kestra:
    image: kestra/kestra:latest
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      KESTRA_STORAGE_TYPE: postgres
      KESTRA_STORAGE_POSTGRES_URI: jdbc:postgresql://postgres:5432/postgres
      KESTRA_STORAGE_POSTGRES_USERNAME: postgres
      KESTRA_STORAGE_POSTGRES_PASSWORD: postgres
      KESTRA_SERVER_BASICAUTH_USERNAME: ${var.kestra_username}
      KESTRA_SERVER_BASICAUTH_PASSWORD: ${var.kestra_password}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 10s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
EOF
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