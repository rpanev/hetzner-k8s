output "master_private_ip" {
  value = [for net in hcloud_server.kube_master.network : net.ip if net.network_id == tonumber(hcloud_network.kube_network.id)][0]
}

output "master_public_ip" {
  description = "The public IPv4 address of the K3s master node"
  value       = hcloud_server.kube_master.ipv4_address
}

#output "master_network_debug" {
#  value = hcloud_server.kube_master.network
#}


#output "worker_public_ips" {
#  value = hcloud_server.kube_workers[*].ipv4_address
#}
