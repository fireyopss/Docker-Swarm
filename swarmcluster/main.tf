
provider "aws" {
    region = var.swarm_details.region
}

resource "tls_private_key" "jumpbox_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jumpbox_key" {
  key_name   = tls_private_key.jumpbox_key.id
  public_key = tls_private_key.jumpbox_key.public_key_openssh
  tags = {
    ClusterName = "${var.swarm_details.cluster_name}"
  }
}

resource "aws_security_group" "jumpbox_sg" {
    
    description = "${var.swarm_details.cluster_name} jumpbox sg"


    tags = {
      ClusterName = "${var.swarm_details.cluster_name}"
    }
}

resource "aws_security_group_rule" "jumpbox_egress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.jumpbox.egress : idx=> rule}

   type              = "egress"

  security_group_id = aws_security_group.jumpbox_sg.id
  cidr_blocks       = each.value.cidr_blocks
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}

resource "aws_security_group_rule" "jumpbox_ingress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.jumpbox.ingress : idx=> rule}

   type              = "ingress"

  security_group_id = aws_security_group.jumpbox_sg.id
  cidr_blocks       = each.value.cidr_blocks
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}




resource "aws_instance" "jumpbox" {
    ami = var.swarm_details.ami
    instance_type = var.swarm_details.jumpbox.instance_type
    key_name = aws_key_pair.jumpbox_key.key_name
    vpc_security_group_ids = [aws_security_group.jumpbox_sg.id]
    tags = {
        Name = "${var.swarm_details.jumpbox.name}"
        ClusterName = "${var.swarm_details.cluster_name}"
    }
}



resource "tls_private_key" "manager_key" {
  for_each =  {for idx,instance in var.swarm_details.managers : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  algorithm = "RSA"
  rsa_bits  = 4096
 
}

resource "aws_key_pair" "manager_key" {
  for_each =  {for idx,instance in var.swarm_details.managers : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  key_name   = "${each.value.name}-key"
  public_key = tls_private_key.manager_key[each.key].public_key_openssh
  tags = {
    ClusterName = "${var.swarm_details.cluster_name}"
  }
}

resource "aws_security_group" "manager_sg" {
    description = "${var.swarm_details.cluster_name} manager sg"


}

resource "aws_security_group_rule" "manager_egress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.manager.egress : idx=> rule}

   type              = "egress"

  security_group_id = aws_security_group.manager_sg.id
  cidr_blocks       = each.value.cidr_blocks
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}

resource "aws_security_group_rule" "manager_ingress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.manager.ingress : idx=> rule}

   type              = "ingress"

  security_group_id = aws_security_group.manager_sg.id
  cidr_blocks       = flatten([
    for cidr in each.value.cidr_blocks : 
    cidr == "jumpbox.ip" ? ["${aws_instance.jumpbox.public_ip}/32"] :
    cidr == "worker.ip" ? [for w in aws_instance.worker_nodes : "${w.public_ip}/32"] :
    [cidr]
    
  ])
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}


resource "aws_instance" "swarm_managers" {
    for_each =  {for idx,instance in var.swarm_details.managers : idx=> instance}
    ami = var.swarm_details.ami
    instance_type = each.value.instance_type
    key_name = aws_key_pair.manager_key[each.key].key_name
    vpc_security_group_ids = [aws_security_group.manager_sg.id]
    tags = {
        ClusterName = "${var.swarm_details.cluster_name}"
        Name = "${each.value.name}"
        ManagerIndex = "${each.key}"
    }
}




resource "tls_private_key" "worker_key" {
  for_each =  {for idx,instance in var.swarm_details.workers : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
    algorithm = "RSA"   
    rsa_bits  = 4096
}

resource "aws_key_pair" "worker_key" {
  for_each =  {for idx,instance in var.swarm_details.workers : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  key_name   = "${each.value.name}-key"
  public_key = tls_private_key.worker_key[each.key].public_key_openssh
  tags = {
    ClusterName = "${var.swarm_details.cluster_name}"
  }
}

resource "aws_security_group" "worker_sg" {

    description = "${var.swarm_details.cluster_name} worker sg"


}

resource "aws_security_group_rule" "worker_ingress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.worker.ingress : idx=> rule}

   type              = "ingress"

  security_group_id = aws_security_group.worker_sg.id
  cidr_blocks       = flatten([
    for cidr in each.value.cidr_blocks : 
    cidr == "jumpbox.ip" ? ["${aws_instance.jumpbox.public_ip}/32"] :
    cidr == "manager.ip" ? [for w in aws_instance.swarm_managers : "${w.public_ip}/32"] :
    [cidr]
    
  ])
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}

resource "aws_security_group_rule" "worker_egress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.worker.egress : idx=> rule}

   type              = "egress"

  security_group_id = aws_security_group.worker_sg.id
  cidr_blocks       = each.value.cidr_blocks
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}

resource "aws_instance" "worker_nodes" {
    for_each =  {for idx,instance in var.swarm_details.workers : idx=> instance}
    ami = var.swarm_details.ami
    instance_type = each.value.instance_type
    key_name = aws_key_pair.worker_key[each.key].key_name
    vpc_security_group_ids = [aws_security_group.worker_sg.id]
    tags = {
        ClusterName = "${var.swarm_details.cluster_name}"
        Name = "${each.value.name}"
        WorkerIndex = "${each.key}"
    }
}


resource "local_file" "jumpbox_private_key" {
  content  = tls_private_key.jumpbox_key.private_key_pem
  filename = "${path.module}/playbooks/keys/jumpbox.pem"
  file_permission = "0400"
}

resource "local_file" "manager_private_key" {
  for_each = aws_key_pair.manager_key
  content  = tls_private_key.manager_key[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/manager_${each.key}.pem"
  file_permission = "0400"
}

resource "local_file" "worker_private_key" {
  for_each = aws_key_pair.worker_key
  content  = tls_private_key.worker_key[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/worker_${each.key}.pem"
    file_permission = "0400"
}

resource "local_file" "ansible_hosts" {
    content  = templatefile("${path.module}/templates/hosts.tftpl", {
        jumpbox_ip = aws_instance.jumpbox.public_ip,
        manager_ips = [for instance in aws_instance.swarm_managers : instance.public_ip],
        worker_ips = [for instance in aws_instance.worker_nodes : instance.public_ip],
        ssh_user = "ubuntu"
    })
    filename = "${path.module}/out/ansible_hosts"
}

