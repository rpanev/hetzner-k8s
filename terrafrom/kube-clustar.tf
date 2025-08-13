data "hcloud_ssh_key" "ssh_key_fingerprint" {
  fingerprint = var.ssh_key_fingerprint
}

# Create master node
resource "hcloud_server" "kube_master" {
  name                    = "${var.node}-master"
  image                   = var.image
  server_type             = var.server_type
  datacenter              = var.datacenter
  ssh_keys                = [data.hcloud_ssh_key.ssh_key_fingerprint.id]
  delete_protection       = var.delete_protection
  rebuild_protection      = var.rebuild_protection
  backups                 = var.backups
  allow_deprecated_images = var.allow_deprecated_images

  labels = {
    env       = "prod"
    terraform = "true"
    ansible   = "true"
    role      = "master"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.kube_network.id
    ip         = "10.0.1.3"
  }

  depends_on = [hcloud_network_subnet.kube_network_subnet]
}

# Configure master node with Ansible
resource "null_resource" "configure_master" {
  depends_on = [hcloud_server.kube_master]

  provisioner "local-exec" {
    command = <<EOT
      ssh-keygen -f ~/.ssh/known_hosts -R ${hcloud_server.kube_master.ipv4_address} || true

      while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa root@${hcloud_server.kube_master.ipv4_address} 'exit'; do
        echo "Waiting for SSH to be available on master node..."
        sleep 10
      done

      ansible-playbook -u root --private-key ~/.ssh/id_rsa \
        -i '${hcloud_server.kube_master.ipv4_address},' \
        ../ansible/install-master.yml \
        --ssh-extra-args='-o StrictHostKeyChecking=no'
    EOT
  }
}

# Create worker node 01
resource "hcloud_server" "kube_worker_1" {
  name        = "${var.node}-worker-1"
  image       = var.image
  server_type = var.server_type
  datacenter  = var.datacenter
  ssh_keys    = [data.hcloud_ssh_key.ssh_key_fingerprint.id]

  labels = {
    role = "worker"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.kube_network.id
    ip         = "10.0.1.20"
  }

  depends_on = [null_resource.configure_master]
}

resource "null_resource" "configure_worker_1" {
  depends_on = [hcloud_server.kube_worker_1]

  provisioner "local-exec" {
    command = <<EOT
      ssh-keygen -f ~/.ssh/known_hosts -R ${hcloud_server.kube_worker_1.ipv4_address} || true

      while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa root@${hcloud_server.kube_worker_1.ipv4_address} 'exit'; do
        echo "Waiting for SSH on worker 1..."
        sleep 10
      done

      ansible-playbook -u root --private-key ~/.ssh/id_rsa \
        -i "${hcloud_server.kube_worker_1.ipv4_address}," \
        ../ansible/install-workers.yml \
        --extra-vars "master_private_ip=10.0.1.3 master_public_ip=${hcloud_server.kube_master.ipv4_address}" \
        --ssh-extra-args='-o StrictHostKeyChecking=no'
    EOT
  }
}

#
resource "hcloud_server" "kube_worker_2" {
  name        = "${var.node}-worker-2"
  image       = var.image
  server_type = var.server_type
  datacenter  = var.datacenter
  ssh_keys    = [data.hcloud_ssh_key.ssh_key_fingerprint.id]

  labels = {
    role = "worker"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.kube_network.id
    ip         = "10.0.1.21"
  }

  depends_on = [null_resource.configure_worker_1]
}

resource "null_resource" "configure_worker_2" {
  depends_on = [hcloud_server.kube_worker_2]

  provisioner "local-exec" {
    command = <<EOT
      ssh-keygen -f ~/.ssh/known_hosts -R ${hcloud_server.kube_worker_2.ipv4_address} || true

      while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa root@${hcloud_server.kube_worker_2.ipv4_address} 'exit'; do
        echo "Waiting for SSH on worker 2..."
        sleep 10
      done

      ansible-playbook -u root --private-key ~/.ssh/id_rsa \
        -i "${hcloud_server.kube_worker_2.ipv4_address}," \
        ../ansible/install-workers.yml \
        --extra-vars "master_private_ip=10.0.1.3 master_public_ip=${hcloud_server.kube_master.ipv4_address}" \
        --ssh-extra-args='-o StrictHostKeyChecking=no'
    EOT
  }
}