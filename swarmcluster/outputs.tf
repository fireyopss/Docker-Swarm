

output "debug1" {
  value = var.swarm_details
}

output "jumpbox_ip" {
  value = aws_instance.jumpbox.public_ip
}

output "manager_ips" {
  value = [for instance in aws_instance.swarm_managers : instance.public_ip]
}

output "worker_ips" {
  value = [for instance in aws_instance.worker_nodes : instance.public_ip]
}