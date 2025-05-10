variable "vultr_api_key" {
  description = "API key for Vultr provider"
  type        = string
  sensitive   = true
}

variable "kestra_username" {
  type        = string
  description = "Kestra basic auth username"
  default     = "stephane.metairie@gmail.com"
}

variable "kestra_password" {
  type        = string
  description = "Kestra basic auth password"
  default     = "kestra"
}
