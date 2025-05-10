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
          test: ["CMD-SHELL", "pg_isready -d ${var.kestra_username} -U ${var.kestra_username}]"]
          interval: 30s
          timeout: 10s
          retries: 10

      kestra:
        image: kestra/kestra:latest
        pull_policy: always
        # Note that this setup with a root user is intended for development purpose.
        # Our base image runs without root, but the Docker Compose implementation needs root to access the Docker socket
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
                  password: "${var.kestra_username}"
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
