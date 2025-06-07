output "vultr_account_info" {
  value = data.vultr_account.current
}

output "default_region" {
  value = local.default_region
}

