provider "openstack" {
}

resource "openstack_compute_secgroup_v2" "secgroup" {
  name        = "${var.cluster_name}_secgroup"
  description = "Slurm+JupyterHub security group"

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    self        = true
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "tcp"
    self        = true
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "udp"
    self        = true
  }

  dynamic "rule" {
    for_each = var.firewall_rules
    content {
      from_port   = rule.value.from_port
      to_port     = rule.value.to_port
      ip_protocol = rule.value.ip_protocol
      cidr        = rule.value.cidr
    }
  }
}

resource "openstack_networking_network_v2" "network" {
  name = "${var.cluster_name}_network"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name        = "${var.cluster_name}_subnet"
  network_id  = openstack_networking_network_v2.network.id
  ip_version  = 4
  cidr        = "10.0.1.0/24"
  no_gateway  = true
  enable_dhcp = true
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = "slurm_cloud_key"
  public_key = var.public_keys[0]
}

resource "openstack_blockstorage_volume_v2" "home" {
  count       = lower(var.storage["type"]) == "nfs" ? 1 : 0
  name        = "${var.cluster_name}_home"
  description = "${var.cluster_name} /home"
  size        = var.storage["home_size"]
}

resource "openstack_blockstorage_volume_v2" "project" {
  count       = lower(var.storage["type"]) == "nfs" ? 1 : 0
  name        = "${var.cluster_name}_project"
  description = "${var.cluster_name} /project"
  size        = var.storage["project_size"]
}

resource "openstack_blockstorage_volume_v2" "scratch" {
  count       = lower(var.storage["type"]) == "nfs" ? 1 : 0
  name        = "${var.cluster_name}_scratch"
  description = "${var.cluster_name} /scratch"
  size        = var.storage["scratch_size"]
}

resource "openstack_compute_instance_v2" "mgmt" {
  count       = var.instances["mgmt"]["count"]
  flavor_name = var.instances["mgmt"]["type"]
  image_name  = var.image
  name        = format("mgmt%02d", count.index + 1)

  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_compute_secgroup_v2.secgroup.name]
  user_data       = data.template_cloudinit_config.mgmt_config[count.index].rendered

  # Networks must be defined in this order
  network {
    name = openstack_networking_network_v2.network.name
  }
  network {
    access_network = true
    name           = var.os_external_network
  }
}

resource "openstack_compute_volume_attach_v2" "va_home" {
  count       = (lower(var.storage["type"]) == "nfs" && var.instances["mgmt"]["count"] > 0) ? 1 : 0
  instance_id = openstack_compute_instance_v2.mgmt[0].id
  volume_id   = openstack_blockstorage_volume_v2.home[0].id
}

resource "openstack_compute_volume_attach_v2" "va_project" {
  count       = (lower(var.storage["type"]) == "nfs" && var.instances["mgmt"]["count"] > 0) ? 1 : 0
  instance_id = openstack_compute_instance_v2.mgmt[0].id
  volume_id   = openstack_blockstorage_volume_v2.project[0].id
  depends_on  = [openstack_compute_volume_attach_v2.va_home]
}

resource "openstack_compute_volume_attach_v2" "va_scratch" {
  count       = (lower(var.storage["type"]) == "nfs" && var.instances["mgmt"]["count"] > 0) ? 1 : 0
  instance_id = openstack_compute_instance_v2.mgmt[0].id
  volume_id   = openstack_blockstorage_volume_v2.scratch[0].id
  depends_on  = [openstack_compute_volume_attach_v2.va_project]
}

resource "openstack_compute_instance_v2" "login" {
  count       = var.instances["login"]["count"]
  flavor_name = var.instances["login"]["type"]
  image_name  = var.image
  name        = format("login%02d", count.index + 1)

  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_compute_secgroup_v2.secgroup.name]
  user_data       = data.template_cloudinit_config.login_config[count.index].rendered

  # Networks must be defined in this order
  network {
    name = openstack_networking_network_v2.network.name
  }
  network {
    access_network = true
    name           = var.os_external_network
  }
}

resource "openstack_compute_instance_v2" "node" {
  count       = var.instances["node"]["count"]
  flavor_name = var.instances["node"]["type"]
  image_name  = var.image
  name        = "node${count.index + 1}"

  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_compute_secgroup_v2.secgroup.name]
  user_data       = data.template_cloudinit_config.node_config[count.index].rendered

  network {
    name = openstack_networking_network_v2.network.name
  }
  network {
    access_network = true
    name           = var.os_external_network
  }
}

locals {
  mgmt01_ip   = openstack_compute_instance_v2.mgmt[0].network[0].fixed_ip_v4
  public_ip   = openstack_compute_instance_v2.login[0].network[1].fixed_ip_v4
  cidr        = openstack_networking_subnet_v2.subnet.cidr
  home_dev    = "/dev/vdb"
  project_dev = "/dev/vdc"
  scratch_dev = "/dev/vdd"
}
