

resource "local_file" "manager_private_key" {
  for_each = aws_key_pair.manager_key
  content  = tls_private_key.manager_key[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/manager_${each.key}_aws.pem"
  file_permission = "0400"
}

resource "local_file" "worker_private_key" {
  for_each = aws_key_pair.worker_key
  content  = tls_private_key.worker_key[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/worker_${each.key}_aws.pem"
    file_permission = "0400"
}

resource "local_file" "manager_private_key_do" {
  for_each = digitalocean_ssh_key.manager_key_do
  content  = tls_private_key.manager_key_do[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/manager_${each.key}_do.pem"
  file_permission = "0400"
}

resource "local_file" "worker_private_key_do" {
  for_each = digitalocean_ssh_key.worker_key_do
  content  = tls_private_key.worker_key_do[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/worker_${each.key}_do.pem"
  file_permission = "0400"
}

resource "local_file" "manager_private_key_linode" {
  for_each = linode_sshkey.manager_key_linode
  content  = tls_private_key.manager_key_linode[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/manager_${each.key}_linode.pem"
  file_permission = "0400"
}

resource "local_file" "worker_private_key_linode" {
  for_each = linode_sshkey.worker_key_linode
  content  = tls_private_key.worker_key_linode[each.key].private_key_pem
  filename = "${path.module}/playbooks/keys/worker_${each.key}_linode.pem"
  file_permission = "0400"
}