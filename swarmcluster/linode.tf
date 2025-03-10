
resource "tls_private_key" "manager_key_linode" {
  for_each =  {for idx,instance in var.manager_nodes_linode : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "linode_sshkey" "manager_key_linode" {
    for_each =  {for idx,instance in var.manager_nodes_linode : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
    label = "manager_key_linode"
  ssh_key = join("", split("\n", tls_private_key.manager_key_linode[each.key].public_key_openssh))
}

resource "linode_instance" "manager_nodes_linode" {
    for_each = {for idx,instance in var.manager_nodes_linode : idx=> instance}
  image  = each.value.image
  label  = each.value.name
  region = each.value.region
  type   = each.value.instance_type
  authorized_keys    = [linode_sshkey.manager_key_linode[each.key].ssh_key]
}


resource "tls_private_key" "worker_key_linode" {
  for_each =  {for idx,instance in var.worker_nodes_linode : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "linode_sshkey" "worker_key_linode" {
    for_each =  {for idx,instance in var.worker_nodes_linode : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
    label = "worker_key_linode"
  ssh_key = join("", split("\n", tls_private_key.worker_key_linode[each.key].public_key_openssh))
}

resource "linode_instance" "worker_nodes_linode" {
    for_each = {for idx,instance in var.worker_nodes_linode : idx=> instance}
  image  = each.value.image
  label  = each.value.name
  region = each.value.region
  type   = each.value.instance_type
  authorized_keys    = [linode_sshkey.worker_key_linode[each.key].ssh_key]
}
