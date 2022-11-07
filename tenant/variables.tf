#=========================#
# ACI                     #
#=========================#

variable "aci_user" {
  description = "The name of the ACI user account"
}
variable "aci_password" {
  description = "The name of the ACI user's password"
}
variable "aci_url" {
  description = "The URL of the APIC"
}

variable "tenant" {
  type = object({
    tenant_self = map(any)
    vrfs        = map(any)
    #    bds         = map(any)
    app_profs = map(any)
    #    l3outs      = map(any)
    #    contracts   = map(any)
    #    filters     = map(any)
  })
}

variable "physDomainName" {
  description = "Name of Physical Domain"
}

variable "annotation" {
  description = "By defautl Terraform will define this as orchestrator:terraform.  Change if you don't want this"
  default     = "orchestrator:terraform"
  #default    = "orchestrator:none"
}