data "template_file" "compose" {
  template = <<-EOT
    volumes:
      db_storage:
      n8n_storage:
      redis_storage:

    x-shared: &shared
      restart: always
      image: docker.n8n.io/n8nio/n8n
      environment:
        - DB_TYPE=postgresdb
        - DB_POSTGRESDB_HOST=postgres
        - DB_POSTGRESDB_PORT=5432
        - DB_POSTGRESDB_DATABASE=${var.postgres_db}
        - DB_POSTGRESDB_USER=${var.postgres_non_root_user}
        - DB_POSTGRESDB_PASSWORD=${var.postgres_non_root_password}
        - EXECUTIONS_MODE=queue
        - QUEUE_BULL_REDIS_HOST=redis
        - QUEUE_HEALTH_CHECK_ACTIVE=true
        - N8N_ENCRYPTION_KEY=${var.encryption_key}
      links:
        - postgres
        - redis
      volumes:
        - n8n_storage:/home/node/.n8n
      depends_on:
        redis:
          condition: service_healthy
        postgres:
          condition: service_healthy

    services:
      postgres:
        image: postgres:16
        restart: always
        environment:
          - POSTGRES_USER
          - POSTGRES_PASSWORD
          - POSTGRES_DB
          - POSTGRES_NON_ROOT_USER
          - POSTGRES_NON_ROOT_PASSWORD
        volumes:
          - db_storage:/var/lib/postgresql/data
          - ./init-data.sh:/docker-entrypoint-initdb.d/init-data.sh
        healthcheck:
          test: ['CMD-SHELL', 'pg_isready -h localhost -U ${var.postgres_user} -d ${var.postgres_db}']
          interval: 5s
          timeout: 5s
          retries: 10

      redis:
        image: redis:6-alpine
        restart: always
        volumes:
          - redis_storage:/data
        healthcheck:
          test: ['CMD', 'redis-cli', 'ping']
          interval: 5s
          timeout: 5s
          retries: 10

      n8n:
        <<: *shared
        ports:
          - 5678:5678

      n8n-worker:
        <<: *shared
        command: worker
        depends_on:
          - n8n
  EOT

  vars = {
    postgres_non_root_user = var.postgres_non_root_user
    postgres_non_root_password = var.postgres_non_root_password
    encryption_key = var.encryption_key
    postgres_user = var.postgres_user
    postgres_db = var.postgres_db
  }
}

resource "local_file" "compose" {
  content  = data.template_file.compose.rendered
  filename = "${path.module}/docker-compose.yaml"
}
