

Docker Swarm Cluster (AWS) Provisioned using terraform and ansible using config yaml file.

This Docker-Swarm Code can provision a multi cloud docker swarm cluster across 3 different cloud provides AWS, Linode and DigitalOcean

Everything is powered by the config.yml

---
environment: "production"
cluster_name: "liveclipper_cluster"

region: "eu-west-3"
ami: "ami-04a4acda26ca36de0"

ssh_key_options:
  generate_auto: true # auto-generate ssh keys and keeps them in state file
  jumpbox_key_path: ""
  worker_key_path: ""
  manager_key_path: ""

The ssh keys are automated if true, otherwise will use the keys specified by the user.


Everything ssh conneciton must go through a jumpbox otherwise known as a bastion node, this is to ensure the connections are secure and do not rely on any individual developers computer.

jumpbox:
  name: "jumpbox"
  instance_type: "t2.nano"
  cloud: "aws"

the config above describes the cloud the jumpbox lives in and the instance type it uses, currently only aws is supported for the jumpbox


The manager nodes config is an array of nodes for example

managers:
  - name: "manager10"
    instance_type: "t2.nano"
    cloud: "aws"
    user: "ubuntu"
 - name: "manager3"
    instance_type: "s-1vcpu-1gb"
    cloud: "do"
    region: "nyc2"
    image: "ubuntu-20-04-x64"
    user: "root"
- name: "manager11"
    instance_type: "g6-nanode-1"
    cloud: "linode"
    region: "us-east"
    user: "root"
    image: "linode/ubuntu22.04"

You can see a range of config options, cloud specifies which cloud it belongs to and user defines the default user, for example in aws ubuntu, ubuntu is the default user however in digitalocean its root.

Workers config is similar

workers:    
  - name: "worker0"
    instance_type: "t2.nano"
    cloud: "aws"
    user: "ubuntu"

The security config is interesting as it controls what ports are open and which ips can access it

security:
  jumpbox:
    egress:
      - from_port: 0
        to_port: 0
        protocol: "-1"
        cidr_blocks:
          - "0.0.0.0/0"
    ingress:
      - from_port: 22
        to_port: 22
        protocol: "tcp"
        cidr_blocks:
          - "92.239.148.217/32" 
the example above specifiys the jumpbox can access the internet, 
and anyone with the ip 92.239.148.217/32 can access port 22 needed for ssh, you may change this to your ip or open it up to the world, it is generally recommended not to do this.


After changing the cluster_name, specifying the region, and ami int he config.yml you may run

terraform apply to spin up the cluster

this will generate a ansible_host file in the swarmcluster/out/ folder