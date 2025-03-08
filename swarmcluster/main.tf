
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

    dynamic "egress" {
        for_each = var.swarm_details.security.jumpbox.egress
        content {
            from_port =  egress.value.from_port
            to_port = egress.value.to_port
            protocol = egress.value.protocol
            cidr_blocks = egress.value.cidr_blocks
        }
    }

    dynamic "ingress" {
        for_each = var.swarm_details.security.jumpbox.ingress
        content {
            from_port =  ingress.value.from_port
            to_port = ingress.value.to_port
            protocol = ingress.value.protocol
            cidr_blocks = ingress.value.cidr_blocks
        }
      
    }

    tags = {
      ClusterName = "${var.swarm_details.cluster_name}"
    }
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

       dynamic "ingress" {
        for_each = var.swarm_details.security.manager.ingress
        content {
            from_port =  ingress.value.from_port
            to_port = ingress.value.to_port
            protocol = ingress.value.protocol
             cidr_blocks = flatten([
                for cidr in ingress.value.cidr_blocks : 
                cidr == "jumpbox.ip" ? ["${aws_instance.jumpbox.public_ip}/32"] :
                cidr == "worker.ip" ? [for w in aws_instance.worker_nodes : "${w.public_ip}/32"] :
                [cidr]
                ])
        }
      
    }

    dynamic "egress" {
        for_each = var.swarm_details.security.manager.egress
        content {
            from_port =  egress.value.from_port
            to_port = egress.value.to_port
            protocol = egress.value.protocol
            cidr_blocks = egress.value.cidr_blocks
        }
      
    }
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


    dynamic "ingress" {
        for_each = var.swarm_details.security.worker.ingress
        content {
            from_port =  ingress.value.from_port
            to_port = ingress.value.to_port
            protocol = ingress.value.protocol
            cidr_blocks = [
                for cidr in ingress.value.cidr_blocks :
                cidr == "jumpbox.ip" ? "${aws_instance.jumpbox.public_ip}/32" : cidr
            ]

            
        }
      
    }


    dynamic "egress" {
        for_each = var.swarm_details.security.worker.egress
        content {
            from_port =  egress.value.from_port
            to_port = egress.value.to_port
            protocol = egress.value.protocol
            cidr_blocks = egress.value.cidr_blocks
        }
      
    }

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