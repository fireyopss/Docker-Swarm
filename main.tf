terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.90.0"
    }
      digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.49.1"
    }
     linode = {
      source = "linode/linode"
      version = "2.34.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

variable "do_token" {
  type = string
}


provider "digitalocean" {
  token = var.do_token
}

variable "linode_token" {
  type = string
}

provider "linode" {
  token = var.linode_token
}

locals {
  swarm_details = yamldecode(file("./config.yml"))
}


module "swarmcluster" {
  source        = "./swarmcluster"
  swarm_details = local.swarm_details
  manager_nodes_aws = {
    for instance in local.swarm_details.managers : instance.name => instance
      if instance.cloud == "aws"
  }
  manager_nodes_do = {
    for instance in local.swarm_details.managers : instance.name => instance
      if instance.cloud == "do"
  }
  manager_nodes_linode = {
    for instance in local.swarm_details.managers : instance.name => instance
      if instance.cloud == "linode"
  }
  worker_nodes_aws = {
    for instance in local.swarm_details.workers : instance.name => instance
      if instance.cloud == "aws"
  }
  worker_nodes_do = {
    for instance in local.swarm_details.workers : instance.name => instance
      if instance.cloud == "do"
  }

  worker_nodes_linode = {
    for instance in local.swarm_details.workers : instance.name => instance
      if instance.cloud == "linode"
  }

  providers = {
    aws = aws
    linode = linode
  }

}



output "debug1" {
  value = module.swarmcluster.debug1
}

output "jumpboxip" {
  value = module.swarmcluster.jumpbox_ip
}

output "manager_ips" {
  value = module.swarmcluster.manager_ips
}

output "worker_ips" {
  value = module.swarmcluster.worker_ips
}