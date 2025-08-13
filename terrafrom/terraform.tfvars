# Hetzner Cloud API token for authentication
hcloud_token = "your_hcloud_token"

# Base name for all servers in the Kubernetes cluster
node                     = "node"

# Number of worker nodes to create (in addition to the master node)
worker_count             = 2

# Operating system image to use (AlmaLinux 9)
image                    = "alma-9"

# Server type/size (cx22: 2 vCPU, 8GB RAM, 80GB SSD)
server_type              = "cx22"

# Datacenter location for server deployment (Falkenstein, Germany)
datacenter               = "fsn1-dc14"

# Datacenter location for load balancer deployment
lb_datacenter            = "fsn1"

# Whether to enable deletion protection for servers
delete_protection        = false

# Whether to enable rebuild protection for servers
rebuild_protection       = false

# Whether to enable automatic backups for servers
backups                  = false

# Whether to allow using deprecated OS images
allow_deprecated_images  = false

# SSH key fingerprint for accessing the servers
ssh_key_fingerprint      = "your_ssh_key_fingerprint"

# Network zone for the private network
network_zone = "eu-central"

# Name of the private network for cluster communication
network_name     = "kube-network"

# IP range for the entire private network (CIDR notation)
ip_range         = "10.0.0.0/16"

# IP range for the subnet within the private network
subnet_ip_cidr  = "10.0.1.0/24"

# Public IP address allowed to access the master node via SSH
ssh_allowed_ip        = "your_ssh_allowed_ip"

# Type of load balancer to create (lb11: Standard load balancer)
load_balancer_type = "lb11"