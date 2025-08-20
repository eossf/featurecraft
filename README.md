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
git config --global user.email "stephane.metairie@gmail.com"
git config --global user.name "Stephane Metairie"

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
