resource "porkbun_dns_record" "n8n_a_record" {
  # This resource creates an A record for the n8n instance on Porkbun
  type   = "A"
  domain = var.porkbun_domain

  content = vultr_instance.current.main_ip
  ttl     = "600"
  prio    = "1"
  notes   = "A Record for vultr n8n instance"
}