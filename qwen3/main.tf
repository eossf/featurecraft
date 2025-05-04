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

data "tls_public_key" "ssh" {
  public_key_pem = file("~/.ssh/id_rsa.pub")
}

resource "vultr_ssh_key" "current" {
  name       = "current-ssh-key"
  ssh_key    = data.tls_public_key.ssh.public_key_openssh

  lifecycle {
    ignore_changes = [ssh_key]
  }
}

resource "vultr_vpc" "cdg" {
  region = "cdg"
  cidr   = "10.0.0.0/24"
}

resource "vultr_reserved_ip" "cdg" {
  region = "cdg"
}

resource "vultr_instance" "kestra" {
  region       = "cdg"
  plan         = "vc2-4c-8gb"
  os_id        = 2284
  label        = "current"
  ssh_keys     = [vultr_ssh_key.current.id]
  vpc_ids      = [vultr_vpc.cdg.id]
  reserved_ip_ids = [vultr_reserved_ip.cdg.id]
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
    command = "ansible-playbook /tmp/install_docker.yaml"
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

resource "null_resource" "upload_docker_compose" {
  depends_on = [local_file.compose]

  connection {
    type        = "ssh"
    host        = vultr_instance.kestra.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    source      = local_file.compose.filename
    destination = "/tmp/docker-compose.yaml"
  }
}

resource "null_resource" "launch_kestra" {
  depends_on = [null_resource.install_docker_with_ansible, local_file.compose]

  connection {
    type        = "ssh"
    host        = vultr_instance.kestra.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    command = "cd /tmp && docker compose up -d --force-recreate --remove-orphans"
  }
}
