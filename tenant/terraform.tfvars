#===============================================================================
# ACI parameters
#===============================================================================

aci_user = "admin"
aci_url  = "https://1.1.1.1"

tenant = {
  ## Tenant itself
  tenant_self = {
    name = "Demo-tf"
  }

  vrfs = {
    "vrfA" = {
      description = ""
    }
    "vrfB" = {
      description = ""
    }
    "vrfC" = {
      description = ""
    }
    "vrfD" = {
      description = ""
    }
    "vrfE" = {
      description = ""
    }
    "vrfF" = {
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