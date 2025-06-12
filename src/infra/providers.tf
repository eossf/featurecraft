provider "vultr" {
  api_key = var.vultr_api_key
}

provider "porkbun" {
  api_key    = var.porkbun_api_key
  secret_key = var.porkbun_secret_api_key
}