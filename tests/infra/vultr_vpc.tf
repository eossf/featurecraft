resource "vultr_vpc" "default_vpc" {
  description    = "private vpc"
  region         = local.default_region
  v4_subnet      = "10.0.0.0"
  v4_subnet_mask = 24
}
