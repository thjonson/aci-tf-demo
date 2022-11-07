terraform {
  required_providers {
    aci = {
      source = "ciscodevnet/aci"
    }
  }
}

#Read int the csvfile used for epg information
locals {
  epg_list = csvdecode(file("../epgs.csv"))
  ports    = csvdecode(file("../access_ports.csv"))
  l3outs   = csvdecode(file("../l3outs.csv"))

  #Break the list of vlans in CSV so each row/map as one vlan
  port-vlans = flatten([
    for inst in local.ports : [
      for vlan in split(",", inst.vlans) : {
        leaf_id      = inst.leaf_id
        port         = inst.port
        vlan         = vlan
        channel_name = inst.ipg_name
        pc_policy    = inst.pc_policy
      }
    ]
  ])

}

#output "port-vlans" {
#  value = local.port-vlans
#}

#configure provider with your cisco aci credentials.
provider "aci" {
  username = var.aci_user
  password = var.aci_password
  url      = var.aci_url
  insecure = true
}

/*
# Create a snapshot before making config changes
resource "aci_rest" "snapshot" {
  path       = "/api/mo.json"
  payload = <<EOF
{
 "configExportP": {
    "attributes": {
     "dn": "uni/fabric/configexp-defaultOneTime",
     "descr": "description of snapshot",
     "adminSt": "triggered"
     }
   }
}
  EOF
}
*/

#Get the tenant information to use later.  When using "terraform destroy" this tenant will NOT be removed
data "aci_tenant" "tenant" {
  name = var.tenant.tenant_self.name
}

resource "aci_vrf" "aci_vrfs" {
  for_each = var.tenant.vrfs

  tenant_dn   = data.aci_tenant.tenant.id
  name        = each.key
  description = each.value.description
  annotation  = var.annotation
}


# Ebable Preferred Groups in VRF to allow EPGs to talk to each other until contracts are created
resource "aci_any" "vzany" {
  for_each = var.tenant.vrfs

  vrf_dn       = aci_vrf.aci_vrfs[each.key].id
  annotation   = var.annotation
  pref_gr_memb = "enabled"
}


# Create a contract to be used for allowing initial traffic before more specific contracts can be added
resource "aci_contract" "allow_all" {
  tenant_dn  = data.aci_tenant.tenant.id
  name       = "Allow_All"
  annotation = var.annotation
  scope      = "context"
}

resource "aci_contract_subject" "allow_all_subject" {
  contract_dn                  = aci_contract.allow_all.id
  name                         = "Allow_All_subject"
  annotation                   = var.annotation
  #relation_vz_rs_subj_filt_att = [aci_filter_entry.allow_all_filter_entry.id]
  relation_vz_rs_subj_filt_att = [aci_filter.allow_all_filter.id]
}

resource "aci_filter_entry" "allow_all_filter_entry" {
  filter_dn   = aci_filter.allow_all_filter.id
  name        = "Allow_All"
  description = ""
  ether_t     = "unspecified"
}

resource "aci_filter" "allow_all_filter" {
  tenant_dn   = data.aci_tenant.tenant.id
  name        = "Allow_All"
  description = ""
}
/*
# Create vzAny contract to allow all EPGs in endpoint to talk to each other until a more specific contract says otherwise
resource "aci_any" "vzany" {
  for_each = var.tenant.vrfs

  vrf_dn                     = aci_vrf.aci_vrfs[each.key].id
  annotation                 = var.annotation
  pref_gr_memb               = "disabled"
  relation_vz_rs_any_to_prov = [aci_contract.allow_all.id]
  relation_vz_rs_any_to_cons = [aci_contract.allow_all.id]
}
*/



#Create bridge domains based on csv file
resource "aci_bridge_domain" "aci_bds" {
  for_each = { for inst in local.epg_list : inst.key => inst }

  tenant_dn          = data.aci_tenant.tenant.id
  name               = "VLAN${each.value.key}_BD"
  unk_mac_ucast_act  = each.value.l2_unk_ucast
  arp_flood          = each.value.arp_flood
  unicast_route      = each.value.unicast_route
  relation_fv_rs_ctx = aci_vrf.aci_vrfs[each.value.vrf].id
  # associate bd with L3Out ** need to make sure L3OUt is created first?...  ******
  relation_fv_rs_bd_to_out = ["${data.aci_tenant.tenant.id}/out-${each.value.l3_out}"]
  #relation_fv_rs_bd_to_out = for k,l in module.l3outs[each.value.l3_out].id
  annotation               = var.annotation
}


#Create subnets in bridge domains if the subnet_needed field is true
resource "aci_subnet" "aci_subnets" {
  for_each = { for inst in local.epg_list : inst.key => inst if inst.subnet_needed }

  parent_dn  = aci_bridge_domain.aci_bds[each.value.key].id
  ip         = each.value.bd_subnet
  scope      = ["public"]
  annotation = var.annotation

}

#Create applicaion profile
resource "aci_application_profile" "aci_aps" {
  for_each = var.tenant.app_profs
  #for_each = { for item in keys(var.tenant.app_profs) : item => item }
  tenant_dn   = data.aci_tenant.tenant.id
  name        = each.key
  description = each.value.description
  annotation  = var.annotation
}

#Create EPGs based on csv file
resource "aci_application_epg" "aci_epgs" {
  for_each = { for inst in local.epg_list : inst.key => inst }

  application_profile_dn = aci_application_profile.aci_aps[each.value.app_prof].id
  name                   = "VLAN${each.value.key}_EPG"
  pref_gr_memb           = "include"
  relation_fv_rs_bd      = aci_bridge_domain.aci_bds[each.key].id
  annotation             = var.annotation
}

#Assign a domain to each EPG.  in this case we're using the same physical domain defined in the tfvars file.
#First, look up the physDom tDn
data "aci_physical_domain" "physical_domain" {
  name       = var.physDomainName
  annotation = var.annotation
}
#Then assign the domain to EPGs
resource "aci_epg_to_domain" "aci_epg_to_domains" {
  for_each = { for inst in local.epg_list : inst.key => inst }

  application_epg_dn = aci_application_epg.aci_epgs[each.value.key].id
  tdn                = data.aci_physical_domain.physical_domain.id
  annotation         = var.annotation
}

/*
# **********  VMM integration for lab work  **************
# **********  VMM integration for lab work  **************
data "aci_vmm_domain" "css_vmmdom" {
  provider_profile_dn = "uni/vmmp-VMware"
  name                = "css-vmm"
}
resource "aci_epg_to_domain" "aci_epg_to_vmm_domain" {
  for_each = { for inst in local.epg_list : inst.key => inst }

  application_epg_dn = aci_application_epg.aci_epgs[each.value.key].id
  tdn                = data.aci_vmm_domain.css_vmmdom.id
}
# **********  VMM integration for lab work  **************
# **********  VMM integration for lab work  **************
*/

#Assign static ports to EPGs (the pc_policy column should be empty)
resource "aci_epg_to_static_path" "aci_epg_to_static_ports" {
  for_each           = { for inst in local.port-vlans : "${inst.leaf_id}-${inst.port}-vl-${inst.vlan}" => inst if inst.pc_policy == "" }
  application_epg_dn = aci_application_epg.aci_epgs[each.value.vlan].id
  tdn                = "topology/pod-1/paths-${each.value.leaf_id}/pathep-[eth1/${each.value.port}]"
  encap              = "vlan-${tonumber(each.value.vlan)}"
  mode               = "regular"
  instr_imedcy       = "immediate"
  annotation         = var.annotation
}

#Assign vPC ports to EPGs (the pc_policy column should NOT be empty)
resource "aci_epg_to_static_path" "aci_epg_to_static_ports_vpc" {
  for_each           = { for inst in local.port-vlans : "${inst.leaf_id}-${inst.channel_name}-vl-${inst.vlan}" => inst if inst.pc_policy != "" }
  application_epg_dn = aci_application_epg.aci_epgs[each.value.vlan].id
  tdn                = "topology/pod-1/protpaths-${each.value.leaf_id}/pathep-[${each.value.channel_name}]"
  #  encap              = "vlan-${tonumber(each.value.vlan)}"
  encap        = format("vlan-%d", each.value.vlan)
  mode         = "regular"
  instr_imedcy = "immediate"
  annotation   = var.annotation
}

# Associate contract to EPGs


# Create a L3Out using the l3outs.csv data file
module "l3outs" {
  source = "./modules/l3outs"

  for_each = { for inst in local.l3outs : inst.name => inst }

  l3_domain_name = each.value.l3_domain_name
  tenant_dn      = data.aci_tenant.tenant.id
  name           = each.value.name
  vrf_dn         = aci_vrf.aci_vrfs[each.value.vrf].id
  nodes          = each.value.nodes
  router_id      = each.value.router_id
  port           = each.value.port
  vlan           = each.value.vlan
  address        = each.value.address
  peer_address   = each.value.peer_address
  peer_address2  = each.value.peer_address2
  peer_as        = each.value.peer_as
  local_as       = each.value.local_as
  subnets        = split(",", each.value.ext_subnets)
  annotation     = var.annotation

}
/*
output "l3outs" {
  value = module.l3outs[*]
}
*/
