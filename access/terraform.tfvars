#===============================================================================
# ACI parameters
#===============================================================================

aci_user = "admin"
aci_url  = "https://1.1.1.1"

tenant = {
  ## Tenant itself
  tenant_self = {
    name        = "Demo-tf"
    description = ""
  }

  vrfs = {
    "VRF1" = {
      description = ""
    }
    "VRF2" = {
      description = ""
    }
  }

  app_profs = {
    "Legacy" = {
      description = ""
    }
  }


}

physDomainName = "baremetal_physDom"