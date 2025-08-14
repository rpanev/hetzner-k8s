# Load Balancer Configuration
resource "hcloud_load_balancer" "load_balancer" {
  name               = "${var.node}-load-balancer"
  load_balancer_type = var.load_balancer_type
  location           = var.lb_datacenter
  delete_protection  = var.delete_protection
  labels = {
    env       = "prod"
    terraform = "true"
    role      = "LoadBalancer"
  }

  depends_on = [hcloud_network.kube_network, hcloud_server.kube_master]
}

# Attach Load Balancer to Network
resource "hcloud_load_balancer_network" "lb_network" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id       = hcloud_network.kube_network.id

  depends_on = [hcloud_network.kube_network, hcloud_load_balancer.load_balancer]
}

# Attach Master Node to the Load Balancer
resource "hcloud_load_balancer_target" "load_balancer_target_master" {
  type             = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id        = hcloud_server.kube_master.id
  use_private_ip   = true

  depends_on = [
    hcloud_network.kube_network,
    hcloud_load_balancer_network.lb_network
  ]
}


# Configure HTTP Service
resource "hcloud_load_balancer_service" "http_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 80

  health_check {
    protocol = "http"
    port     = 80
    interval = 15
    timeout  = 10
    retries  = 3
    http {
      path = "/"
      status_codes = ["2??"]
    }
  }

  depends_on = [hcloud_load_balancer.load_balancer]
}

# # Configure HTTPS Service
# # Забележка: За да използвате HTTPS, трябва да имате валиден SSL сертификат в Hetzner Cloud
# # Закоментирайте този блок, ако нямате сертификат или променете certificates с вашия ID
# resource "hcloud_load_balancer_service" "https_service" {
#   load_balancer_id = hcloud_load_balancer.load_balancer.id
#   protocol         = "https"
#   listen_port      = 443
#   destination_port = 443

#   http {
#     # Заменете с вашия сертификат ID или използвайте променлива
#     certificates = []
#   }

#   health_check {
#     protocol = "https"
#     port     = 443
#     interval = 15
#     timeout  = 10
#     retries  = 3
#     http {
#       path = "/"
#       status_codes = ["2??", "3??"]
#     }
#   }

#   depends_on = [hcloud_load_balancer.load_balancer]
# }

# Configure Kubernetes API Service
resource "hcloud_load_balancer_service" "kubernetes_api_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443

  health_check {
    protocol = "tcp"
    port     = 6443
    interval = 10
    timeout  = 5
    retries  = 3
  }

  depends_on = [hcloud_load_balancer.load_balancer]
}