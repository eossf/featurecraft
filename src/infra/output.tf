output "vultr_account_info" {
  value = data.vultr_account.current
}

output "default_region" {
  value = local.default_region
}

output "vultr_instance_ip" {
  value = vultr_instance.current.main_ip
}

output "porkbun_dns_record" {
 value =  porkbun_dns_record.n8n_a_record
}