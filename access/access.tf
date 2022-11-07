terraform {
  required_providers {
    aci = {
      source = "ciscodevnet/aci"
    }
  }
}

# Read int the csvfile used for epg information
locals {
  port_list = csvdecode(file("../access_ports.csv"))
  # Get unique list of nodes to create NodeProfiles for
  node_list = toset([for inst in local.port_list : inst.leaf_id])
}
output "name" {
  value = local.node_list
  
}

# Configure provider with your cisco aci credentials.
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

# Leaf Interface Profiles (should probably just reference these once fabric is setup)
# also need to make sure swtich profiles are associated with these interface selector profiles
/*
resource "aci_leaf_interface_profile" "leaf_interface_profile_101" {
  name = "Leaf101_IntProf"
}

resource "aci_leaf_interface_profile" "leaf_interface_profile_102" {
  name = "Leaf102_IntProf"
}

resource "aci_leaf_interface_profile" "leaf_interface_profile_101-102" {
  name = "Leaf101-102_IntProf"
}
*/

resource "aci_leaf_interface_profile" "leaf_interface_profile" {
  for_each = local.node_list
  name = "Leaf${each.value}_IntProfW"
}




# Associate Interface Selectors with Leaf Interface Profiles
resource "aci_access_port_selector" "leaf_access_port_selectors" {
  for_each = { for inst in local.port_list : inst.ipg_name => inst }

  name                      = "${each.key}_portSel"
  description               = each.value.description
#  leaf_interface_profile_dn = "uni/infra/accportprof-Leaf${each.value.leaf_id}_IntProf"
  leaf_interface_profile_dn = aci_leaf_interface_profile.leaf_interface_profile[each.value.leaf_id].id
  access_port_selector_type = "range"
  relation_infra_rs_acc_base_grp = merge(aci_leaf_access_port_policy_group.leaf_access_port_policy_groups,
  aci_leaf_access_bundle_policy_group.leaf_vpc_policy_groups)[each.value.ipg_name].id
}

# Associate physical ports for Interface Selectors
resource "aci_access_port_block" "leaf_access_port_blocks" {
  for_each = { for inst in local.port_list : inst.ipg_name => inst }

  access_port_selector_dn = aci_access_port_selector.leaf_access_port_selectors[each.key].id
  name                    = "${each.value.ipg_name}_portBlock"
  from_card               = 1
  from_port               = each.value.port
  to_card                 = 1
  to_port                 = each.value.port

}

# Be sure to create the Interface Policies (like cdp_enabled) before applying these
# Leaf access port interface policy groups (single connection)
resource "aci_leaf_access_port_policy_group" "leaf_access_port_policy_groups" {
  for_each = { for inst in local.port_list : inst.ipg_name => inst if inst.pc_policy == "" }

  name                                   = each.key
  description                            = each.value.description
  relation_infra_rs_att_ent_p            = each.value.aaep != "" ? "uni/infra/attentp-${each.value.aaep}" : ""
  relation_infra_rs_h_if_pol             = each.value.link_level != "" ? "uni/infra/hintfpol-${each.value.link_level}" : ""
  relation_infra_rs_cdp_if_pol           = each.value.cdp != "" ? "uni/infra/cdpIfP-${each.value.cdp}" : ""
  relation_infra_rs_lldp_if_pol          = each.value.lldp != "" ? "uni/infra/lldpIfP-${each.value.lldp}" : ""
  relation_infra_rs_l2_port_security_pol = each.value.port_sec != "" ? "uni/infra/portsecurityP-${each.value.port_sec}" : ""

}

# Leaf VPC interface policy groups
resource "aci_leaf_access_bundle_policy_group" "leaf_vpc_policy_groups" {
  for_each = { for inst in local.port_list : inst.ipg_name => inst if inst.pc_policy != "" }

  name                                   = each.key
  description                            = each.value.description
  lag_t                                  = "node"   # node is for vPC; link is for port-channel
  relation_infra_rs_att_ent_p            = each.value.aaep != "" ? "uni/infra/attentp-${each.value.aaep}" : ""
  relation_infra_rs_h_if_pol             = each.value.link_level != "" ? "uni/infra/hintfpol-${each.value.link_level}" : ""
  relation_infra_rs_cdp_if_pol           = each.value.cdp != "" ? "uni/infra/cdpIfP-${each.value.cdp}" : ""
  relation_infra_rs_lldp_if_pol          = each.value.lldp != "" ? "uni/infra/lldpIfP-${each.value.lldp}" : ""
  relation_infra_rs_l2_port_security_pol = each.value.port_sec != "" ? "uni/infra/portsecurityP-${each.value.port_sec}" : ""
  relation_infra_rs_lacp_pol             = each.value.pc_policy != "" ? "uni/infra/lacplagp-${each.value.pc_policy}" : ""

}
