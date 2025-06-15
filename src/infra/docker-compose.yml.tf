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
        - DB_POSTGRESDB_PASSWORD="${var.postgres_non_root_password}"
        - EXECUTIONS_MODE=queue
        - QUEUE_BULL_REDIS_HOST=redis
        - QUEUE_HEALTH_CHECK_ACTIVE=true
        - N8N_ENCRYPTION_KEY="${var.n8n_encryption_key}"
        # - N8N_BASIC_AUTH_ACTIVE=false
        # - N8N_BASIC_AUTH_USER=${var.n8n_basic_auth_user}
        # - N8N_BASIC_AUTH_PASSWORD="${var.n8n_password}"
        - N8N_API_KEY="${var.n8n_api_key}"
        - N8N_GENERIC_AUTH_ENABLED=true
        - N8N_RUNNERS_ENABLED=true
        - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
        - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
        - N8N_SECURE_COOKIE=false
      links:
        - postgres
        - redis
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

      n8n:
        <<: *shared
        ports:
          - 5678:5678
        volumes:
          - n8n_storage:/home/node/.n8n 
          - /var/run/docker.sock:/var/run/docker.sock
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:5678/healthz"]
          interval: 10s
          timeout: 5s
          retries: 5

      n8n-worker:
        <<: *shared
        ports:
          - 5679:5679
        volumes:
          - n8n_storage:/home/node/.n8n
        command: worker
        depends_on:
          - n8n
        
      # nginx:
      #   image: nginx:alpine
      #   container_name: nginx
      #   ports:
      #     - "443:443"
      #   volumes:
      #     - ./nginx.conf:/etc/nginx/nginx.conf:ro
      #     - ./domain.cert.pem:/etc/ssl/certs/domain.cert.pem:ro
      #     - ./private.key.pem:/etc/ssl/private/private.key.pem:ro
      #   restart: unless-stopped

  EOT

  vars = {
    n8n_basic_auth_user        = var.n8n_basic_auth_user
    encryption_key             = var.n8n_encryption_key
    n8n_password               = var.n8n_password
    n8n_user                   = var.n8n_user
    pinecone_api_key          = var.pinecone_api_key
    postgres_db                = var.postgres_db
    postgres_non_root_password = var.postgres_non_root_password
    postgres_non_root_user     = var.postgres_non_root_user
    postgres_password          = var.postgres_password
    postgres_user              = var.postgres_user
  }
}

resource "local_file" "compose" {
  content  = data.template_file.compose.rendered
  filename = "${path.module}/docker-compose.yaml"
}
