# Feature Craft

## Installation platform

### Domain and certificate

I have my own domain (metairie.dev) and a Lets Encrypt certificate bundle for https

To import certificate, conversion for windows

```bash
openssl pkcs12 -export \
  -out domain.pfx \
  -inkey private.key.pem \
  -in domain.cert.pem
```

### DNS

My registrar manager, allows me to add A record for my IP address. Also https://metairie.dev/ goes to this setup by default

### Start from Windows PC (gitbash and powershell)

#### Github runner locally installed version 2.325

Run as local administrator, INSTALL AS SERVICE when prompt, put your own RUNNER_TOKEN

```powershell
    # into git root folder
    mkdir actions-runner; cd actions-runner

    Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.325.0/actions-runner-win-x64-2.325.0.zip -OutFile actions-runner-win-x64-2.325.0.zip

    if((Get-FileHash -Path actions-runner-win-x64-2.325.0.zip -Algorithm SHA256).Hash.ToUpper() -ne '8601aa56828c084b29bdfda574af1fcde0943ce275fdbafb3e6d4a8611245b1b'.ToUpper()){ throw 'Computed checksum did not match' }

    Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner-win-x64-2.325.0.zip", "$PWD")

    ./config.cmd --url https://github.com/eossf/featurecraft --token <RUNNER_TOKEN>

    # if not as service
    ./run.cmd
```

#### Run locally in gitbash

```bash
cd src/infra
source ./export_TF_VARS.sh
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply

# remove compose file generation 
terraform destroy -target null_resource.launch
terraform destroy -target local_file.compose
```

## BUILD platform



## RUN platform



### Test Demo 

#### kubernetes
 - data helm ok
 - pdf version 


## API

```bash
curl -k -X "GET" "https://$TF_VAR_domain/api/v1/workflows?active=true" \
  -H "accept: application/json" \
  -H "'X-N8N-API-KEY: $TF_VAR_n8n_api_key'"

curl -k -X "GET" "https://$TF_VAR_domain/api/v1/workflows?active=true" \
  -H "accept: application/json" -H "'Authorization: Bearer $TF_VAR_n8n_api_key'" -H "'X-N8N-API-KEY: $TF_VAR_n8n_api_key'"
```

### Run plateform in Docker

```bash
docker run -it --rm --name n8n -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  docker.n8n.io/n8nio/n8n
```

docker run -it --rm --name n8n -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_HOST=metairie.dev \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=https \
  -e NODE_ENV=production \
  -e WEBHOOK_URL=https://metairie.dev/ \
  -e GENERIC_TIMEZONE="Europe/Paris" \
  -e OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true  docker.n8n.io/n8nio/n8n

  -e N8N_ENCRYPTION_KEY="Q2FzZV9zZW5zaXRpdmVfZW5jcnlwdGlvbl9rZXlfZXhhbXBsZQ==" \
  -e N8N_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2YTgyMzU0MC1mNjc1LTQ4ZDEtYTliYy01ZmM4NWM5ZmY3ZDciLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzQ5NjY2NTI4fQ.p_m3ZzYXlLbYNjgc6dTqXMfqsM7YJVibDSRffcTz1cI" \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=postgres \
  -e DB_POSTGRESDB_PORT=5432 \
  -e DB_POSTGRESDB_DATABASE=n8n \
  -e DB_POSTGRESDB_USER=featurecraft \
  -e DB_POSTGRESDB_PASSWORD="yT7!pQ2wZx9@Lm4s" \
  -e EXECUTIONS_MODE=queue \
  -e QUEUE_BULL_REDIS_HOST=redis \
  -e QUEUE_HEALTH_CHECK_ACTIVE=true \