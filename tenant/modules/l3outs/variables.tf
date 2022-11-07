/*
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
*/

variable "l3_domain_name" {
  description = "Name of L3 Domain"
}

variable "tenant_dn" {
  description = "Name of Tenant"
}
variable "name" {
  description = "Name of L3Out - will be used to name L3Out as well as sub-policy names"
}
variable "vrf_dn" {
  description = "Distinguished name of the VRF"
}

variable "nodes" {
  
}

variable "router_id" {
  
}

variable "port" {
  
}

variable "vlan" {
  
}

variable "address" {
  
}
variable "peer_address" {
  
}
variable "peer_address2" {
  
}
variable "peer_as" {
  
}
variable "local_as" {
  
}
variable "subnets" {
  
}
variable "annotation" {
  
}