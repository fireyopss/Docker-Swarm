

output "debug1" {
  value = var.swarm_details
}

output "jumpbox_ip" {
  value = aws_instance.jumpbox.public_ip
}

output "manager_ips" {
  value = flatten([
    [for instance in aws_instance.swarm_managers : instance.public_ip],
    [for droplet in digitalocean_droplet.manager_nodes_do : droplet.ipv4_address],
    [for instance in linode_instance.manager_nodes_linode : instance.ipv4]
  ])
}

output "worker_ips" {
  value = flatten([
     [for instance in aws_instance.worker_nodes : instance.public_ip],
      [for droplet in digitalocean_droplet.worker_nodes_do : droplet.ipv4_address],
      [for instance in linode_instance.worker_nodes_linode : instance.ipv4]
  ])
}

