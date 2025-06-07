terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.26.0"
    }
    tls   = { source = "hashicorp/tls" }
    local = { source = "hashicorp/local" }
    null  = { source = "hashicorp/null" }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

variable "vultr_api_key" {
  description = "API key for Vultr"
  type        = string
  sensitive   = true
}

variable "kestra_username" {
  description = "Username for Kestra basic auth"
  type        = string
  default     = "stephane.metairie@gmail.com"
}

variable "kestra_password" {
  description = "Password for Kestra basic auth"
  type        = string
  default     = "kestra"
  sensitive   = true
}

data "vultr_account" "current" {}

data "vultr_region" "default_region" {
  filter {
    name   = "DCID"
    values = ["cdg"]
  }
}

resource "vultr_ssh_key" "default" {
  name    = "current-ssh-key"
  ssh_key = file("~/.ssh/id_rsa.pub")
  lifecycle {
    ignore_changes = [ssh_key]
  }
}

resource "vultr_vpc" "default_vpc" {
  description = "Kestra VPC"
  region      = data.vultr_region.default_region.id
  network     = "10.0.0.0/24"
}

resource "vultr_reserved_ip" "default" {
  region = data.vultr_region.default_region.id
  type   = "ipv4"
}

resource "vultr_instance" "current" {
  label          = "current"
  plan           = "vc2-4c-8gb"
  os_id          = 2284
  region         = data.vultr_region.default_region.id
  ipv4_address   = vultr_reserved_ip.default.ip_address
  vpc_network_id = vultr_vpc.default_vpc.id
  ssh_key_ids    = [vultr_ssh_key.default.id]
}

resource "null_resource" "install_ansible" {
  depends_on = [vultr_instance.current]

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
      "add-apt-repository ppa:ansible/ansible -y",
      "apt-get install ansible -y"
    ]
  }
}

data "template_file" "install_docker" {
  template = <<EOF
- hosts: all
  become: true
  tasks:
    - name: Install Docker
      shell: curl -fsSL https://get.docker.com | sh
EOF
}

resource "local_file" "install_docker_yml" {
  content  = data.template_file.install_docker.rendered
  filename = "install_docker.yaml"
}

resource "null_resource" "install_docker_with_ansible" {
  depends_on = [null_resource.install_ansible, local_file.install_docker_yml]

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "install_docker.yaml"
    destination = "/root/install_docker.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "ansible-playbook /root/install_docker.yaml -i '${vultr_instance.current.main_ip},' --private-key ~/.ssh/id_rsa -u root"
    ]
  }
}

data "template_file" "compose" {
  template = <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: kestra
      POSTGRES_DB: kestra
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kestra"]
      interval: 10s
      timeout: 5s
      retries: 5

  kestra:
    image: kestra/kestra:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - KESTRA_DATABASE_URL=jdbc:postgresql://postgres:5432/kestra
      - KESTRA_REPOSITORY=kubernetes
      - KESTRA_AUTH_BASIC_USERNAME=${var.kestra_username}
      - KESTRA_AUTH_BASIC_PASSWORD=${var.kestra_password}
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
EOF
}

resource "local_file" "compose" {
  content  = data.template_file.compose.rendered
  filename = "docker-compose.yaml"
}

resource "null_resource" "upload_compose" {
  depends_on = [local_file.compose]

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "docker-compose.yaml"
    destination = "/root/docker-compose.yaml"
  }
}

resource "null_resource" "launch_kestra" {
  depends_on = [null_resource.install_docker_with_ansible, null_resource.upload_compose]

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "docker compose -f /root/docker-compose.yaml up -d --force-recreate --remove-orphans"
    ]
  }
}
