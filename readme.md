# Multi-Cloud Docker Swarm

Provision a Docker Swarm cluster across AWS, DigitalOcean, and Linode using Terraform and Ansible—all configured through a single YAML file.

## Features

- **Multi-cloud support** - Deploy nodes across AWS, DigitalOcean, and Linode in a single cluster
- **Configuration-driven** - Define your entire infrastructure in `config.yml`
- **Secure by default** - All SSH connections route through a jumpbox/bastion host
- **Automatic SSH keys** - Generate keys automatically or bring your own
- **Flexible node placement** - Mix and match clouds for managers and workers

## Prerequisites

- [Terraform](https://www.terraform.io/) >= 1.0
- [Ansible](https://www.ansible.com/) >= 2.9
- Cloud provider credentials:
  - AWS credentials configured (`aws configure`)
  - DigitalOcean API token
  - Linode API token

## Quick Start

1. **Clone and configure**
   ```bash
   git clone <repo-url>
   cd Docker-Swarm
   ```

2. **Edit `config.yml`** to define your cluster (see Configuration below)

3. **Deploy infrastructure**
   ```bash
   terraform init
   terraform apply \
     -var="do_token=YOUR_DIGITALOCEAN_TOKEN" \
     -var="linode_token=YOUR_LINODE_TOKEN"
   ```

4. **Run Ansible to initialize the swarm**
   ```bash
   ansible-playbook -i swarmcluster/out/hosts swarmcluster/playbooks/setup.yml
   ```

## Configuration

All infrastructure is defined in `config.yml`:

### Basic Settings

```yaml
environment: "production"
cluster_name: "my_cluster"
aws_region: "eu-west-3"
```

### SSH Keys

```yaml
ssh_key_options:
  generate_auto: true   # Auto-generate and store in Terraform state
  jumpbox_key_path: ""  # Or specify paths to existing keys
  worker_key_path: ""
  manager_key_path: ""
```

### Jumpbox (Bastion Host)

The jumpbox acts as a secure gateway—all SSH connections to cluster nodes pass through it.

```yaml
jumpbox:
  name: "jumpbox"
  instance_type: "t2.nano"
  user: "ubuntu"
  cloud: "aws"
  image: "ami-04a4acda26ca36de0"
```

> Currently, the jumpbox must be on AWS.

### Manager Nodes

```yaml
managers:
  - name: "manager1"
    instance_type: "t2.nano"
    cloud: "aws"
    user: "ubuntu"
    image: "ami-04a4acda26ca36de0"

  - name: "manager2"
    instance_type: "s-1vcpu-1gb"
    cloud: "do"
    region: "nyc2"
    user: "root"
    image: "ubuntu-20-04-x64"

  - name: "manager3"
    instance_type: "g6-nanode-1"
    cloud: "linode"
    region: "us-east"
    user: "root"
    image: "linode/ubuntu22.04"
```

### Worker Nodes

```yaml
workers:
  - name: "worker1"
    instance_type: "t2.nano"
    cloud: "aws"
    user: "ubuntu"
    image: "ami-04a4acda26ca36de0"

  - name: "worker2"
    instance_type: "s-1vcpu-1gb"
    cloud: "do"
    region: "nyc2"
    user: "root"
    image: "ubuntu-20-04-x64"
```

### Node Configuration Reference

| Field | Description |
|-------|-------------|
| `name` | Unique node identifier (becomes hostname) |
| `instance_type` | Cloud-specific instance size |
| `cloud` | `aws`, `do`, or `linode` |
| `user` | SSH user (`ubuntu` for AWS, `root` for DO/Linode) |
| `image` | AMI ID (AWS) or image slug (DO/Linode) |
| `region` | Required for DO and Linode nodes |

### Security Rules

Control network access with ingress/egress rules:

```yaml
security:
  jumpbox:
    ingress:
      - from_port: 22
        to_port: 22
        protocol: "tcp"
        cidr_blocks:
          - "YOUR.PUBLIC.IP/32"  # Restrict SSH to your IP
    egress:
      - from_port: 0
        to_port: 0
        protocol: "-1"
        cidr_blocks:
          - "0.0.0.0/0"

  manager:
    ingress:
      - from_port: 22
        to_port: 22
        protocol: "tcp"
        cidr_blocks:
          - "jumpbox.ip"
      - from_port: 2377
        to_port: 2377
        protocol: "tcp"
        cidr_blocks:
          - "worker.ip"
          - "manager.ip"
    # ... additional rules

  worker:
    ingress:
      - from_port: 22
        to_port: 22
        protocol: "tcp"
        cidr_blocks:
          - "jumpbox.ip"
    # ... additional rules
```

Special CIDR values:
- `jumpbox.ip` - Resolves to jumpbox public IP
- `manager.ip` - Resolves to all manager IPs
- `worker.ip` - Resolves to all worker IPs

## Outputs

After `terraform apply`, you'll get:

- **jumpboxip** - Public IP of the bastion host
- **manager_ips** - List of manager node IPs
- **worker_ips** - List of worker node IPs

Generated files in `swarmcluster/out/`:
- `hosts` - Ansible inventory
- `jumpbox_ssh_config` - SSH config for bastion access

## Connecting to Nodes

Use the generated SSH config to connect through the jumpbox:

```bash
ssh -F swarmcluster/out/jumpbox_ssh_config manager1
```

## Architecture

```
                    ┌─────────────┐
                    │   Jumpbox   │
                    │    (AWS)    │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────┴────┐       ┌─────┴────┐       ┌─────┴────┐
   │ Manager │       │ Manager  │       │ Manager  │
   │  (AWS)  │       │  (DO)    │       │ (Linode) │
   └────┬────┘       └────┬─────┘       └────┬─────┘
        │                 │                  │
        └─────────────────┼──────────────────┘
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
   ┌────┴────┐       ┌────┴────┐       ┌─────┴────┐
   │ Worker  │       │ Worker  │       │  Worker  │
   │  (AWS)  │       │  (DO)   │       │ (Linode) │
   └─────────┘       └─────────┘       └──────────┘
```

## Cleanup

```bash
terraform destroy \
  -var="do_token=YOUR_DIGITALOCEAN_TOKEN" \
  -var="linode_token=YOUR_LINODE_TOKEN"
```
