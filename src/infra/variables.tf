variable "n8n_encryption_key" {
  description = "The encryption key used by n8n for encrypting sensitive data"
  type        = string
  sensitive   = true
}

variable "n8n_password" {
  type      = string
  sensitive = true
}

variable "n8n_user" {
  type = string
}

variable "postgres_db" {
  type = string
}

variable "postgres_non_root_password" {
  type = string
}

variable "postgres_non_root_user" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_user" {
  type = string
}

variable "vultr_api_key" {
  description = "API key for Vultr provider"
  type        = string
  sensitive   = true
}

variable "porkbun_api_key" {
  description = "API key for Porkbun provider"
  type        = string
  sensitive   = true
}

variable "porkbun_secret_api_key" {
  description = "Secret API key for Porkbun provider"
  type        = string
  sensitive   = true
}

variable "porkbun_domain" {
  description = "Domain name for the application"
  type        = string
}

variable "n8n_api_key" {
  description = "API key for n8n instance"
  type        = string
  sensitive   = true
}