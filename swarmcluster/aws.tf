terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
   linode = {
      source = "linode/linode"
      version = "2.34.2"
    }
       digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.49.1"
    }
  }
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
  for_each =  {for idx,instance in var.manager_nodes_aws : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
  algorithm = "RSA"
  rsa_bits  = 4096
 
}

resource "aws_key_pair" "manager_key" {
  for_each =  {for idx,instance in var.manager_nodes_aws : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
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

//allows manager to communicate with jumpbox
resource "aws_security_group_rule" "manager_ingress_2377_docker" {
    type              = "ingress"
    security_group_id = aws_security_group.manager_sg.id
    source_security_group_id = aws_security_group.manager_sg.id
    from_port         = 0
    protocol          = "tcp"
    to_port           = 0
}

resource "aws_security_group_rule" "manager_ingress_23772_docker" {
    type              = "ingress"
    security_group_id = aws_security_group.manager_sg.id
    source_security_group_id = aws_security_group.manager_sg.id
    from_port         = 0
    protocol          = "udp"
    to_port           = 0
}

resource "aws_security_group_rule" "manager_ingress_rules" {

  for_each = {for idx,rule in var.swarm_details.security.manager.ingress : idx=> rule}

   type              = "ingress"

  security_group_id = aws_security_group.manager_sg.id
  cidr_blocks       = flatten([
    for cidr in each.value.cidr_blocks : 
    cidr == "jumpbox.ip" ? ["${aws_instance.jumpbox.public_ip}/32"] :
    cidr == "manager.ip" ? flatten([
      [for w in aws_instance.swarm_managers : "${w.public_ip}/32"],
      [for w in digitalocean_droplet.manager_nodes_do : "${w.ipv4_address}/32"],
      [for w in linode_instance.manager_nodes_linode : "${join("", w.ipv4)}/32"]
    ]):
    cidr == "worker.ip" ? flatten([
       [for w in aws_instance.worker_nodes : "${w.public_ip}/32"],
        [for w in digitalocean_droplet.worker_nodes_do : "${w.ipv4_address}/32"],
        [for w in linode_instance.worker_nodes_linode : "${join("", w.ipv4)}/32"]
    ]) :
    [cidr]
    
  ])
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port

}


resource "aws_instance" "swarm_managers" {
    for_each =  {for idx,instance in var.manager_nodes_aws : idx=> instance}
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
  for_each =  {for idx,instance in var.worker_nodes_aws : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
    algorithm = "RSA"   
    rsa_bits  = 4096
}

resource "aws_key_pair" "worker_key" {
  for_each =  {for idx,instance in var.worker_nodes_aws : idx=> instance if var.swarm_details.ssh_key_options.generate_auto}
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
    cidr == "manager.ip" ? flatten([
      [for w in aws_instance.swarm_managers : "${w.public_ip}/32"],
      [for w in digitalocean_droplet.manager_nodes_do : "${w.ipv4_address}/32"],
      [for w in linode_instance.manager_nodes_linode : "${join("", w.ipv4)}/32"]
    ]) :
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
    for_each =  {for idx,instance in var.worker_nodes_aws : idx=> instance}
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



resource "local_file" "ansible_hosts" {
    content  = templatefile("${path.module}/templates/hosts.tftpl", {
        cluter_name = var.swarm_details.cluster_name,
        jumpbox_ip = aws_instance.jumpbox.public_ip,
        managers_config = var.swarm_details.managers,
        workers_config = var.swarm_details.workers,
        manager_ips = flatten([
           [for instance in aws_instance.swarm_managers : instance.public_ip],
           [for droplet in digitalocean_droplet.manager_nodes_do : droplet.ipv4_address],
           [for instance in linode_instance.manager_nodes_linode : instance.ipv4]
        ]),
        worker_ips = flatten([
          [for instance in aws_instance.worker_nodes : instance.public_ip],
          [for droplet in digitalocean_droplet.worker_nodes_do : droplet.ipv4_address],
          [for instance in linode_instance.worker_nodes_linode : instance.ipv4]
        ]),
        ssh_user = "ubuntu"
    })
    filename = "${path.module}/out/ansible_hosts"
}

resource "local_file" "jumpboxsshconfigfile" {
        content  = templatefile("${path.module}/templates/configssh.tftpl", {

      jumpbox_ip = aws_instance.jumpbox.public_ip,
        manager_ips = [for instance in aws_instance.swarm_managers : instance.public_ip],
        worker_ips = [for instance in aws_instance.worker_nodes : instance.public_ip],
        ssh_user = "ubuntu"
        })
            filename = "${path.module}/out/jumpbox_ssh_config"

}

resource "local_file" "bastion_ssh_config" {
    content= templatefile("${path.module}/templates/bastionconfig.tftpl",{
        cluster_name = var.swarm_details.cluster_name,
        jumpbox_ip = aws_instance.jumpbox.public_ip,
        full_path_to_private_key = abspath(local_file.jumpbox_private_key.filename),
        ssh_user = "ubuntu"
    })
    filename = "${path.module}/playbooks/keys/bastion_ssh_config"
}


# resource "linode_sshkey" "foo" {
#   label = "foo"
#   ssh_key = chomp(file("~/.ssh/id_rsa.pub"))
# }


# provider "digitalocean" {
#   token = ""
  
# }


# resource "tls_private_key" "do_ssh_key" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }


# resource "digitalocean_ssh_key" "default" {
#   name       = "Terraform Example"
#   public_key = tls_private_key.do_ssh_key.public_key_openssh
# }