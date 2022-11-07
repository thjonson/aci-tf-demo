
data "aci_l3_domain_profile" "l3_domain_profile" {
  name = var.l3_domain_name
  annotation     = var.annotation
}

resource "aci_l3_outside" "l3_outside" {

  tenant_dn                    = var.tenant_dn
  name                         = "${var.name}-l3out"
  relation_l3ext_rs_ectx       = var.vrf_dn
  relation_l3ext_rs_l3_dom_att = data.aci_l3_domain_profile.l3_domain_profile.id
  #enforce_rtctrl = ["export", "import"]
  annotation     = var.annotation
}

resource "aci_logical_node_profile" "logical_node_profile" {
  l3_outside_dn = aci_l3_outside.l3_outside.id
  name          = "${var.name}-NodeProf"
  annotation     = var.annotation
}

resource "aci_logical_node_to_fabric_node" "logical_node_to_fabric_node" {
  logical_node_profile_dn = aci_logical_node_profile.logical_node_profile.id
  tdn                     = "topology/pod-1/node-${var.nodes}"
  rtr_id                  = var.router_id
  rtr_id_loop_back        = "no"
  annotation     = var.annotation
}

resource "aci_logical_interface_profile" "logical_interface_profile" {
  logical_node_profile_dn = aci_logical_node_profile.logical_node_profile.id
  name                    = "${var.name}-IntfProf"
  annotation     = var.annotation
}

resource "aci_l3out_path_attachment" "l3out_path_attachment" {
  logical_interface_profile_dn = aci_logical_interface_profile.logical_interface_profile.id
  target_dn = "topology/pod-1/paths-${var.nodes}/pathep-[eth${var.port}]"
  if_inst_t = "ext-svi"
  encap     = "vlan-${var.vlan}"
  mtu       = "1500"
  addr      = var.address
  annotation     = var.annotation
}

# Enable BGP protocol for the L3Out
resource "aci_l3out_bgp_external_policy" "l3out_bgp_external_policy" {
  l3_outside_dn = aci_l3_outside.l3_outside.id
  annotation     = var.annotation
}

resource "aci_bgp_peer_connectivity_profile" "bgp_peer_connectivity_profile" {
  parent_dn = aci_l3out_path_attachment.l3out_path_attachment.id
  addr                    = var.peer_address
  as_number               = var.peer_as
  local_asn               = var.local_as
  #password               = "secret"
  annotation     = var.annotation
}

resource "aci_bgp_peer_connectivity_profile" "bgp_peer_connectivity_profile_2" {
  parent_dn = aci_l3out_path_attachment.l3out_path_attachment.id
  addr                    = var.peer_address2
  as_number               = var.peer_as
  local_asn               = var.local_as
  #password               = "secret"
  annotation     = var.annotation
}

resource "aci_external_network_instance_profile" "external_network_instance_profile" {
  l3_outside_dn = aci_l3_outside.l3_outside.id
  name          = "${var.name}-ExtEPG"
  pref_gr_memb   = "include"
  annotation     = var.annotation
}

resource "aci_l3_ext_subnet" "l3_ext_subnet" {
  for_each = toset(var.subnets)

  external_network_instance_profile_dn = aci_external_network_instance_profile.external_network_instance_profile.id
  ip                                   = each.value
  scope                                = ["import-security"]
  annotation     = var.annotation
}


/*output "subnets" {
  value = var.subnets
}*/