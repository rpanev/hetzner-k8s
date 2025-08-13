# Private Network
# Main network
resource "hcloud_network" "kube_network" {
  name     = var.network_name
  ip_range = var.ip_range
  labels = {
    env       = "prod"
    terraform = "true"
  }
}

# Subnet within the network
resource "hcloud_network_subnet" "kube_network_subnet" {
  type         = "cloud"
  network_id   = hcloud_network.kube_network.id
  network_zone = var.network_zone
  ip_range     = var.subnet_ip_cidr
}

### Firewall Configuration // TODO: Add firewall configuration
# resource "hcloud_firewall" "kube_firewall" {
#   name = "kube-fw"
#
#   # Allow SSH only from the specified IP
#   rule {
#     direction   = "in"
#     protocol    = "tcp"
#     port        = "22"
#     source_ips  = [var.ssh_allowed_ip]
#     description = "Allow SSH access only from your IP"
#   }
#   
#   # Allow K8S API only from the specified IP
#   rule {
#     direction   = "in"
#     protocol    = "tcp"
#     port        = "6443"
#     source_ips  = [var.ssh_allowed_ip]
#     description = "Allow K8S API only from the specified IP"
#   }
#
#   # Allow all outgoing TCP traffic
#   rule {
#     direction       = "out"
#     protocol        = "tcp"
#     port            = "1-65535"
#     destination_ips = ["0.0.0.0/0"]
#     description     = "Allow all outgoing TCP traffic"
#   }
#
#   # Allow all outgoing UDP traffic
#   rule {
#     direction       = "out"
#     protocol        = "udp"
#     port            = "1-65535"
#     destination_ips = ["0.0.0.0/0"]
#     description     = "Allow all outgoing UDP traffic"
#   }
#
#   # Allow all outgoing ICMP traffic
#   rule {
#     direction       = "out"
#     protocol        = "icmp"
#     destination_ips = ["0.0.0.0/0"]
#     description     = "Allow all outgoing ICMP traffic"
#   }
# }

## Firewall Attachment // TODO: Add firewall attachment
# resource "hcloud_firewall_attachment" "kube_firewall_attachment" {
#   firewall_id = hcloud_firewall.kube_firewall.id
#   server_ids  = concat([hcloud_server.kube_master.id], hcloud_server.kube_workers[*].id)
# }