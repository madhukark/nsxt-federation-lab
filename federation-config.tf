################################################################################
#
# Terraform configuration file for NSX-T Federation Lab
#
# Terraform config run through PowerCLI script
#
################################################################################

# Global Manager
provider "nsxt" {
  host                 = "10.114.200.40"
  username             = "admin"
  password             = "myPassword1!myPassword1!"
  global_manager       = "true"
  allow_unverified_ssl = true
}

# New Yark Site
provider "nsxt" {
  alias                = "ny"
  host                 = "10.114.200.41"
  username             = "admin"
  password             = "myPassword1!myPassword1!"
  allow_unverified_ssl = true
}

# Paris Site
provider "nsxt" {
  alias                = "paris"
  host                 = "10.114.200.42"
  username             = "admin"
  password             = "myPassword1!myPassword1!"
  allow_unverified_ssl = true
}

# Londong Site
provider "nsxt" {
  alias                = "london"
  host                 = "10.114.200.43"
  username             = "admin"
  password             = "myPassword1!myPassword1!"
  allow_unverified_ssl = true
}


data "nsxt_policy_site" "ny" {
  display_name = "nsx-ny"
}

data "nsxt_policy_site" "paris" {
  display_name = "nsx-paris"
}

data "nsxt_policy_site" "london" {
  display_name = "nsx-london"
}

data "nsxt_policy_transport_zone" "ny_overlay_tz" {
  display_name = "nsx-overlay-transportzone"
  site_path    = data.nsxt_policy_site.ny.path
}

data "nsxt_policy_transport_zone" "paris_overlay_tz" {
  display_name = "nsx-overlay-transportzone"
  site_path    = data.nsxt_policy_site.paris.path
}

data "nsxt_policy_transport_zone" "london_overlay_tz" {
  display_name = "nsx-overlay-transportzone"
  site_path    = data.nsxt_policy_site.london.path
}

data "nsxt_policy_transport_zone" "paris_tz" {
  provider     = nsxt.paris
  display_name = "nsx-overlay-transportzone"
}

data "nsxt_policy_transport_zone" "london_tz" {
  provider     = nsxt.london
  display_name = "nsx-overlay-transportzone"
}

data "nsxt_policy_edge_cluster" "ny" {
  display_name = "Edge-Cluster-ny"
  site_path    = data.nsxt_policy_site.ny.path
}

data "nsxt_policy_edge_cluster" "paris" {
  display_name = "Edge-Cluster-paris"
  site_path    = data.nsxt_policy_site.paris.path
}

data "nsxt_policy_edge_cluster" "london" {
  display_name = "Edge-Cluster-london"
  site_path    = data.nsxt_policy_site.london.path
}

data "nsxt_policy_edge_node" "london_edge1" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.london.path
  member_index      = 0
}

resource "nsxt_policy_tier0_gateway" "global_t0" {
  display_name  = "Global-T0"
  nsx_id        = "Global-T0"
  description   = "Tier-0 with Global scope"
  failover_mode = "PREEMPTIVE"
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.paris.path
  }
  locale_service {
    edge_cluster_path    = data.nsxt_policy_edge_cluster.london.path
    preferred_edge_paths = [data.nsxt_policy_edge_node.london_edge1.path]
  }
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.ny.path
  }
  tag {
    tag = "terraform"
  }
}

data "nsxt_policy_realization_info" "global_t0_info_ny" {
  path        = nsxt_policy_tier0_gateway.global_t0.path
  entity_type = "RealizedLogicalRouter"
  site_path   = data.nsxt_policy_site.ny.path
}

data "nsxt_policy_realization_info" "global_t0_info_paris" {
  path        = nsxt_policy_tier0_gateway.global_t0.path
  entity_type = "RealizedLogicalRouter"
  site_path   = data.nsxt_policy_site.paris.path
}

data "nsxt_policy_realization_info" "global_t0_info_london" {
  path        = nsxt_policy_tier0_gateway.global_t0.path
  entity_type = "RealizedLogicalRouter"
  site_path   = data.nsxt_policy_site.london.path
}


resource "nsxt_policy_bgp_config" "global_bgp_t0" {
  site_path             = data.nsxt_policy_site.paris.path
  gateway_path          = nsxt_policy_tier0_gateway.global_t0.path
  enabled               = true
  inter_sr_ibgp         = true
  local_as_num          = 60001
  graceful_restart_mode = "HELPER_ONLY"
  route_aggregation {
    prefix       = "20.1.0.0/24"
    summary_only = false
  }
}

resource "nsxt_policy_tier1_gateway" "ny_t1" {
  display_name = "Ny-T1"
  nsx_id       = "Ny-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.ny.path
  }
  tag {
    tag = "terraform"
  }
  depends_on = [data.nsxt_policy_realization_info.global_t0_info_ny]
}

resource "nsxt_policy_tier1_gateway" "paris_t1" {
  provider     = nsxt.paris
  display_name = "Paris-T1"
  nsx_id       = "Paris-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.paris.path
  }
  tag {
    tag = "terraform"
  }
  depends_on = [data.nsxt_policy_realization_info.global_t0_info_paris]
}

resource "nsxt_policy_tier1_gateway" "london_t1" {
  provider     = nsxt.london
  display_name = "London-T1"
  nsx_id       = "London-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.london.path
  }
  tag {
    tag = "terraform"
  }
  depends_on = [data.nsxt_policy_realization_info.global_t0_info_london]
}

resource "nsxt_policy_tier1_gateway" "paris_london_t1" {
  display_name = "Paris-London-T1"
  nsx_id       = "Paris-London-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.paris.path
  }
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.london.path
  }
  intersite_config {
    primary_site_path = data.nsxt_policy_site.paris.path
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_tier1_gateway" "global_t1" {
  display_name = "Global-T1"
  nsx_id       = "Global-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "global_segment" {
  display_name      = "Global-Segment"
  nsx_id            = "Global-Segment"
  connectivity_path = nsxt_policy_tier1_gateway.global_t1.path
  subnet {
    cidr = "40.40.40.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "ny_segment" {
  display_name      = "Ny-Segment"
  nsx_id            = "Ny-Segment"
  connectivity_path = nsxt_policy_tier1_gateway.ny_t1.path
  subnet {
    cidr = "41.41.41.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "paris_segment" {
  provider            = nsxt.paris
  display_name        = "Paris-Segment"
  nsx_id              = "Paris-Segment"
  connectivity_path   = nsxt_policy_tier1_gateway.paris_t1.path
  transport_zone_path = data.nsxt_policy_transport_zone.paris_tz.path
  subnet {
    cidr = "42.42.42.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "london_segment" {
  provider            = nsxt.london
  display_name        = "London-Segment"
  nsx_id              = "London-Segment"
  connectivity_path   = nsxt_policy_tier1_gateway.london_t1.path
  transport_zone_path = data.nsxt_policy_transport_zone.london_tz.path
  subnet {
    cidr = "43.43.43.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_nat_rule" "nat_ny_t1" {
  display_name         = "DNAT_Rule1"
  action               = "DNAT"
  source_networks      = ["9.10.1.1"]
  destination_networks = ["11.10.1.1"]
  translated_networks  = ["10.10.1.1"]
  gateway_path         = nsxt_policy_tier1_gateway.ny_t1.path
  firewall_match       = "MATCH_INTERNAL_ADDRESS"
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_nat_rule" "nat_paris_london_t1" {
  display_name         = "NAT_Rule1"
  action               = "DNAT"
  source_networks      = ["9.40.1.1", "9.50.1.1"]
  destination_networks = ["11.60.1.1"]
  translated_networks  = ["10.60.1.1"]
  gateway_path         = nsxt_policy_tier1_gateway.paris_london_t1.path
  firewall_match       = "MATCH_INTERNAL_ADDRESS"
  tag {
    tag = "terraform"
  }
}

data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

data "nsxt_policy_service" "icmp" {
  display_name = "ICMP ALL"
}

resource "nsxt_policy_group" "ny_group" {
  display_name = "ny-group"
  nsx_id       = "ny-group"
  domain       = data.nsxt_policy_site.ny.id
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "ny"
    }
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_group" "paris_group" {
  display_name = "paris-group"
  nsx_id       = "paris-group"
  domain       = data.nsxt_policy_site.paris.id
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "paris"
    }
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_security_policy" "ny-paris-policy" {
  display_name = "Ny-Paris-SSH"
  nsx_id       = "Ny-Paris-SSH"
  category     = "Application"
  stateful     = true
  rule {
    display_name       = "Ny-Paris-SSH"
    source_groups      = [nsxt_policy_group.ny_group.path]
    destination_groups = [nsxt_policy_group.paris_group.path]
    services           = [data.nsxt_policy_service.ssh.path]
    action             = "ALLOW"
  }
  rule {
    display_name       = "Paris-Ny-SSH"
    source_groups      = [nsxt_policy_group.paris_group.path]
    destination_groups = [nsxt_policy_group.ny_group.path]
    services           = [data.nsxt_policy_service.ssh.path]
    action             = "ALLOW"
  }
  rule {
    display_name       = "Ny-Paris-ICMP"
    source_groups      = [nsxt_policy_group.ny_group.path]
    destination_groups = [nsxt_policy_group.paris_group.path]
    services           = [data.nsxt_policy_service.icmp.path]
    action             = "ALLOW"
  }
  rule {
    display_name       = "Paris-Ny-ICMP"
    source_groups      = [nsxt_policy_group.paris_group.path]
    destination_groups = [nsxt_policy_group.ny_group.path]
    services           = [data.nsxt_policy_service.icmp.path]
    action             = "ALLOW"
  }
  tag {
    tag = "terraform"
  }
}

