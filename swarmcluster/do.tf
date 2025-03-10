

resource "tls_private_key" "manager_key_do" {
  for_each =  {for idx,instance in var.manager_nodes_do : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "digitalocean_ssh_key" "manager_key_do" {
  for_each =  {for idx,instance in var.manager_nodes_do : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  name       = "manager_key_do"
  public_key = tls_private_key.manager_key_do[each.key].public_key_openssh
}

resource "digitalocean_droplet" "manager_nodes_do" {
  for_each = {for idx,instance in var.manager_nodes_do : idx=> instance}
  image   = each.value.image
  name    = each.value.name
  region  = each.value.region
  size    = each.value.instance_type
  ssh_keys = [digitalocean_ssh_key.manager_key_do[each.key].id]
}


resource "tls_private_key" "worker_key_do" {
  for_each =  {for idx,instance in var.worker_nodes_do : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
    algorithm = "RSA"   
    rsa_bits  = 4096
}

resource "digitalocean_ssh_key" "worker_key_do" {
  for_each =  {for idx,instance in var.worker_nodes_do : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}

  name = "worker_key_do"
  public_key = tls_private_key.worker_key_do[each.key].public_key_openssh
}


resource "digitalocean_droplet" "worker_nodes_do" {
  for_each = {for idx,instance in var.worker_nodes_do : idx=> instance}
  image   = each.value.image
  name    = each.value.name
  region  = each.value.region
  size    = each.value.instance_type
  ssh_keys = [digitalocean_ssh_key.worker_key_do[each.key].id]
}

