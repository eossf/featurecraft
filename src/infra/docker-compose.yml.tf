data "template_file" "compose" {
  template = <<-EOT
    volumes:
      db_storage:
      n8n_storage:
      redis_storage:

    services:
      nginx:
        image: nginx:alpine
        container_name: nginx
        ports:
          - "443:443"
        volumes:
          - ./nginx.conf:/etc/nginx/nginx.conf:ro
          - ./domain.cert.pem:/etc/ssl/certs/domain.cert.pem:ro
          - ./private.key.pem:/etc/ssl/private/private.key.pem:ro
        depends_on:
          - n8n
        restart: unless-stopped
        
      n8n:
        restart: always
        image: docker.n8n.io/n8nio/n8n
        environment:
          - DB_TYPE=postgresdb
          - DB_POSTGRESDB_HOST=postgres
          - DB_POSTGRESDB_PORT=5432
          - DB_POSTGRESDB_DATABASE=${var.postgres_db}
          - DB_POSTGRESDB_USER=${var.postgres_non_root_user}
          - DB_POSTGRESDB_PASSWORD="${var.postgres_non_root_password}"
          - EXECUTIONS_MODE=queue
          - QUEUE_BULL_REDIS_HOST=redis
          - QUEUE_HEALTH_CHECK_ACTIVE=true
          - N8N_ENCRYPTION_KEY="${var.encryption_key}"
          - N8N_BASIC_AUTH_ACTIVE=true
          - N8N_BASIC_AUTH_USER=${var.n8n_user}
          - N8N_BASIC_AUTH_PASSWORD="${var.n8n_password}"
        links:
          - postgres
          - redis
        volumes:
          - n8n_storage:/home/node/.n8n
        ports:
          - 5678:5678
        depends_on:
          # traefik:
          #   condition: service_healthy
          redis:
            condition: service_healthy
          postgres:
            condition: service_healthy

      postgres:
        image: postgres:16
        restart: always
        environment:
          - POSTGRES_USER=${var.postgres_user}
          - POSTGRES_PASSWORD="${var.postgres_password}"
          - POSTGRES_DB=n8n
          - POSTGRES_NON_ROOT_USER=${var.postgres_non_root_user}
          - POSTGRES_NON_ROOT_PASSWORD="${var.postgres_non_root_password}"
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
  EOT

  vars = {
    postgres_non_root_user     = var.postgres_non_root_user
    postgres_non_root_password = var.postgres_non_root_password
    # The encryption key used by n8n for encrypting sensitive data
    encryption_key    = var.encryption_key
    postgres_user     = var.postgres_user
    domain            = var.domain
    n8n_user          = var.n8n_user
    n8n_password      = var.n8n_password
    postgres_password = var.postgres_password
    n8n_password      = var.n8n_password
  }
}

resource "local_file" "compose" {
  content  = data.template_file.compose.rendered
  filename = "${path.module}/docker-compose.yaml"
}
