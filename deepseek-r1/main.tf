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

provider "vultr" {
  api_key = var.vultr_api_key
}

data "vultr_region" "default_region" {
  filter {
    name   = "id"
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
  region         = data.vultr_region.default_region.id
  v4_subnet      = "10.0.0.0"
  v4_subnet_mask = 24
}

resource "vultr_reserved_ip" "default" {
  region = data.vultr_region.default_region.id
  ip_type = "v4"
}

resource "vultr_instance" "current" {
  region           = data.vultr_region.default_region.id
  plan             = "vc2-4c-8gb"
  os_id            = 2284
  label            = "current"
  ssh_key_ids      = [vultr_ssh_key.default.id]
  vpc_ids        = [vultr_vpc.default_vpc.id]
  reserved_ip_id = vultr_reserved_ip.default.id
}

resource "null_resource" "install_ansible" {
  triggers = {
    instance_id = vultr_instance.current.id
  }

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

data "template_file" "docker_playbook" {
  template = <<-EOT
    - hosts: localhost
      tasks:
        - name: Install Docker
          shell: curl -fsSL https://get.docker.com | sh
  EOT
}

resource "null_resource" "install_docker_with_ansible" {
  triggers = {
    playbook = data.template_file.docker_playbook.rendered
  }

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    content     = data.template_file.docker_playbook.rendered
    destination = "/root/install_docker.yaml"
  }

  provisioner "remote-exec" {
    inline = ["ansible-playbook /root/install_docker.yaml"]
  }

  depends_on = [null_resource.install_ansible]
}

data "template_file" "compose" {
  template = <<-EOT
version: '3'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: kestra
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: kestra
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kestra -d kestra"]
      interval: 5s
      timeout: 5s
      retries: 5

  kestra:
    image: kestra/kestra:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      KESTRA_CONFIGURATION_STORE_POSTGRES_HOST: postgres
      KESTRA_CONFIGURATION_STORE_POSTGRES_USERNAME: kestra
      KESTRA_CONFIGURATION_STORE_POSTGRES_PASSWORD: kestra
      KESTRA_CONFIGURATION_STORE_POSTGRES_DATABASE: kestra
      KESTRA_CONFIGURATION_STORE_TYPE: postgres
      KESTRA_SERVER_BASIC_AUTH_ENABLED: "true"
      KESTRA_SERVER_BASIC_AUTH_USERNAME: "${var.kestra_username}"
      KESTRA_SERVER_BASIC_AUTH_PASSWORD: "${var.kestra_password}"
    ports:
      - "8080:8080"
    volumes:
      - kestra_data:/app/storage

volumes:
  postgres_data:
  kestra_data:
  EOT
}

resource "local_file" "compose" {
  filename = "docker-compose.yaml"
  content  = data.template_file.compose.rendered
}

resource "null_resource" "upload_compose" {
  triggers = {
    compose_content = data.template_file.compose.rendered
  }

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "file" {
    source      = local_file.compose.filename
    destination = "/root/docker-compose.yaml"
  }

  depends_on = [local_file.compose]
}

resource "null_resource" "launch_kestra" {
  triggers = {
    compose = data.template_file.compose.rendered
  }

  connection {
    type        = "ssh"
    host        = vultr_instance.current.main_ip
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = ["docker compose -f /root/docker-compose.yaml up -d --force-recreate --remove-orphans"]
  }

  depends_on = [
    null_resource.install_docker_with_ansible,
    null_resource.upload_compose
  ]
}