variable "node" {
  description = "Base name for all servers in the Kubernetes cluster"
  type        = string
  default     = "node"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "image" {
  description = "Image to use for the server"
  type        = string
}

variable "server_type" {
  description = "Server type/size"
  type        = string
}

variable "datacenter" {
  description = "Datacenter to deploy the server in"
  type        = string
}

variable "lb_datacenter" {
  description = "Datacenter to deploy the LB in"
  type        = string
}


variable "delete_protection" {
  description = "Enable or disable delete protection"
  type        = bool
  default     = false
}

variable "rebuild_protection" {
  description = "Enable or disable rebuild protection"
  type        = bool
  default     = false
}

variable "backups" {
  description = "Enable or disable backups"
  type        = bool
  default     = false
}

variable "allow_deprecated_images" {
  description = "Allow deprecated images to be used"
  type        = bool
  default     = false
}

variable "ssh_key_fingerprint" {
  description = "SSH key fingerprint for accessing the servers"
  type        = string
}

variable "network_zone" {
  description = "The network zone to deploy the network in"
  type        = string
}

variable "ip_range" {
  description = "The IP range for the network"
  type        = string
}

variable "network_name" {
  description = "The name of the network"
  type        = string
}

variable "subnet_ip_cidr" {
  description = "The IP range for the subnet"
  type        = string
}

variable "ssh_allowed_ip" {
  description = "Public IP allowed to access master node via SSH"
  type        = string
}

variable "load_balancer_type" {
  description = "value"
  type = string
}