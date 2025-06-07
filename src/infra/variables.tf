variable "vultr_api_key" {
  description = "API key for Vultr provider"
  type        = string
  sensitive   = true
}

variable "postgres_non_root_user" {
  type        = string
  default     = "me"
}

variable "postgres_non_root_password" {
  type        = string
  default     = "mypassword"
}

variable "encryption_key" {
  type        = string
  default     = "123345678901234567890123456789012"
  sensitive   = true
}

variable "postgres_user" {
  type        = string
  default     = "user"
}

variable "postgres_db" {
  type        = string
  default     = "db"
}