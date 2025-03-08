terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.90.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

locals {
  swarm_details = yamldecode(file("./infra.yml"))
}


module "swarmcluster" {
  source        = "./swarmcluster"
  swarm_details = local.swarm_details
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