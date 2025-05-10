data "vultr_region" "default_region" {
  filter {
    name   = "id"
    values = ["cdg"]
  }
}

locals {
  default_region = data.vultr_region.default_region.id
}
