terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.31.0"
    }
    # porkbun = {
    #   source  = "kyswtn/porkbun"
    #   version = "0.1.3"
    # }
    porkbun = {
      source  = "cullenmcdermott/porkbun"
      version = "0.3.0"
    }
  }
}
