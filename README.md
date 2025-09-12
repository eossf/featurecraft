# Feature Craft

The purpose of this project is to provide a bot that helps create, update, maintain a standard kubernetes project.

Use cases: add a new feature, advisor, maintain, ... 

How to use ? This is the workflow expected:
 - assign a ticket to the bot in a Kubernetes Project,
 - the pipeline CICD starts the bot,
 - the bot does the expected work,
 - the bot creates a PR/MR,

## Requirements

Support only this tools and version for the moment:

 - github
 - kubectl and git latest
 - training data 

## Features

 - request/reply,
 - create/update code repository,
 - git lifecycle,
 - history and memory (redo the fix at any time - outcome is stable),
 - kubernetes trained LLM,
 - chatbot for asking about kubernetes,
 - tools kubectl, git, ...
 - a report with benchmark is written for every run,

## How it's working

This project build an OCI image embedding kubectl, LLMs, MCP, workflow engine, git, training data, ... 

Once the container is running, run a command.


## 1/ Install platform
### 1a/ Pre-requisites
#### Domain and certificate

I have my own domain (metairie.dev) and a Lets Encrypt certificate bundle for https

To import certificate, let's do a conversion for windows user (.pfx)

```bash
# for windows only
openssl pkcs12 -export \
  -out domain.pfx \
  -inkey private.key.pem \
  -in domain.cert.pem
```

#### DNS

My registrar manager, allows me to add A record for my IP address. Also https://metairie.dev/ goes to this setup by default

### 1b/ CI - Github runner
#### Locally installed version 2.325 - Windows
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

### 1c/ Run locally in bash (.devcontainer) or gitbash

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

## 2/ RUN the platform
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

# Future implementation

#TODO replace private_key = file("/home/.ssh/id_rsa") => ${HOME}

#TODO experimental design
Multi layers Bot. The update for a ticket could target one of these layers.
- specifications
- code infra
- code app
- configuration

The bot should be onboard the first time it is launched, for discovering:
- code repository
- documentation project, specificities
- versions of components and dependancies
- general behaviour (conservative/... configuration files not managed by IA, ...)
