# Hetzner Cloud K3s Cluster with Terraform + Ansible

Automated deployment of a K3s Kubernetes cluster on Hetzner Cloud, using Infrastructure as Code principles with Terraform and Ansible.

![Hetzner Cloud Kubernetes Server](.img/hetzner_cloud.png)

## 📋 Contents

1. [Overview and Architecture](#overview-and-architecture)
2. [Prerequisites](#prerequisites)
3. [Step 1: SSH Key Setup](#step-1-ssh-key-setup)
4. [Step 2: Configuration](#step-2-configuration)
5. [Step 3: Infrastructure Deployment](#step-3-infrastructure-deployment)
6. [Step 4: Cluster Access](#step-4-cluster-access)
7. [Step 5: Testing the Cluster](#step-5-testing-the-cluster)
8. [Step 6: Cleanup (Optional)](#step-6-cleanup-optional)
9. [Advanced Topics](#advanced-topics)
10. [Troubleshooting](#troubleshooting)

## Overview and Architecture

### What This Project Does
- **Creates servers** on Hetzner Cloud using Terraform
- **Configures a K3s cluster** using Ansible
- **Organizes resources** with networks and tags
- **Provides testing tools** for validation

### Architecture Components
- **1 Master node** (k3s server) - manages the Kubernetes control plane
- **2 Worker nodes** (k3s agents) - run workloads and pods
- **Private network** for communication (10.0.1.0/24)
- **Automated SSH key management** for secure access
- **Load Balancer** for service access

### Important Notes
- ✅ **Tested on**: AlmaLinux 9 servers
- 🔧 **Requirements**: Hetzner Cloud API token and SSH keys

## Prerequisites

Before you begin, make sure you have:

### On Your Local Machine
- **Terraform** >= 1.0
- **Ansible** >= 2.9
- **kubectl** (for cluster management)
- **git** (for repository cloning)
- **hcloud CLI** (optional, for managing Hetzner Cloud resources)

### In Hetzner Cloud
- **Hetzner Cloud account** with API access
- **API token** with full permissions
- **SSH key** added to your Hetzner Cloud account

## Step 1: SSH Key Setup

Before deploying the cluster, you need to generate SSH keys for secure access.

### 1.1 Generating Keys for Terraform/Ansible Access

These keys will be used by Terraform and Ansible for accessing and configuring the servers:

```bash
# Generate SSH key pair for external access
ssh-keygen -t ed25519 -C "terraform@hetzner.dev" -f ~/.ssh/id_ed25519

# Set proper permissions
chmod 600 ~/.ssh/id_ed25519
```

**When prompted, press enter to leave the passphrase empty.**

### 1.2 Generating Keys for K3s Cluster Node Communication

These keys enable secure communication between cluster nodes:

```bash
# Create directory for ansible keys
mkdir -p ansible/keys/

# Generate RSA key pair for cluster communication
ssh-keygen -t rsa -b 2048 -C "k3s-cluster@hetzner" -f ansible/keys/k3s_cluster_key

# Set proper permissions
chmod 600 ansible/keys/k3s_cluster_key
chmod 644 ansible/keys/k3s_cluster_key.pub
```

**When prompted, press enter to leave the passphrase empty.**

### Key Summary
- **`~/.ssh/id_ed25519`**: External access from your machine to the servers
- **`ansible/keys/k3s_cluster_key`**: Communication between nodes in the cluster
- **Security**: Keys are excluded from git via `.gitignore`

## Step 2: Configuration

Now configure the project for your environment.

### 2.1 Navigate to the Terraform Directory

```bash
cd terrafrom/
```

### 2.2 Configure terraform.tfvars

Edit `terraform.tfvars` with the details for your environment:

```hcl
# Hetzner Cloud API access
hcloud_token = "your-hetzner-cloud-api-token"

# Infrastructure
node                     = "node"
worker_count             = 2
image                    = "alma-9"
server_type              = "cx22"
datacenter               = "fsn1-dc14"

# Network configuration
network_zone = "eu-central"
network_name = "kube-network"
ip_range     = "10.0.0.0/16"
subnet_ip_cidr = "10.0.1.0/24"

# SSH access
ssh_key_fingerprint = "51:b1:4d:17:30:a9:d3:c4:57:1f:bf:c9:63:8a:96:3a"
ssh_allowed_ip      = "your-public-ip"

# Load Balancer // TODO: Add load balancer configuration
load_balancer_type = "lb11" 
```

### Configuration Parameters Explanation

| Parameter | Description | Example |
|-----------|-------------|--------|
| `hcloud_token` | Hetzner Cloud API token | `your-hetzner-cloud-api-token` |
| `node` | Base name for nodes | `node` |
| `worker_count` | Number of worker nodes | `2` |
| `image` | Server image | `alma-9` |
| `server_type` | Server type | `cx22` |
| `datacenter` | Data center | `fsn1-dc14` |
| `network_zone` | Network zone | `eu-central` |
| `ssh_key_fingerprint` | Your SSH key fingerprint | Copy from Hetzner Cloud console |

**Important**: Add your Hetzner Cloud API token in the `hcloud_token` field or use the hcloud CLI configuration.

## Step 3: Infrastructure Deployment

Now deploy the K3s cluster infrastructure.

### 3.1 Automated Deployment (Recommended)

Return to the project's root directory and run the deployment script:

```bash
# Return to the project root directory
cd ..

# Run the automated deployment script
./deploy.sh
```

**What the script does:**
- ✅ Checks all prerequisites (SSH keys, configuration files, tools)
- ✅ Shows a deployment summary with your configuration
- ✅ Executes terraform init, validate, plan, and apply automatically
- ✅ Triggers Ansible playbooks to configure K3s
- ✅ Provides post-deployment instructions
- ✅ Handles errors gracefully with colored output

### 3.2 Manual Deployment (Alternative)

If you prefer manual control:

```bash
cd terrafrom/
terraform init
terraform validate
terraform plan
terraform apply
```

**Confirm terraform apply by typing "yes" and wait for deployment to complete.**

### 3.3 What Happens During Deployment

1. **Terraform Phase** (5-10 minutes):
   - Creates servers in Hetzner Cloud
   - Configures networks and storage
   - Sets up SSH access

2. **Ansible Phase** (5-10 minutes):
   - Installs K3s on the master node
   - Configures worker nodes
   - Sets up cluster networking
   - Distributes SSH keys

**Total deployment time: ~10-20 minutes**

## Infrastructure Destruction

When you need to completely remove the K3s cluster and all related resources:

### Option 1: Using the Automated Destruction Script (Recommended)

```bash
# Run the automated destruction script from the project root directory
./destroy.sh
```

The script will:
- Check prerequisites and show what will be destroyed
- Automatically backup your kubeconfig file
- Create a destruction plan and request confirmation
- Require typing 'DESTROY' in capital letters for final confirmation
- Safely remove all servers, networks, and configurations
- Provide post-destruction cleanup recommendations

### Option 2: Manual Destruction

```bash
cd terrafrom/
terraform plan -destroy
terraform destroy
```

⚠️ **Warning**: Destroying the infrastructure will permanently delete:
- All servers and their data
- All Kubernetes workloads and persistent volumes
- All cluster configurations
- Hetzner Cloud networks and load balancer

This action cannot be undone!

## Ansible Integration

Ansible is automatically triggered by Terraform through `null_resource` provisioners. The process:

1. **Terraform creates servers** with configuration
2. **Waits for SSH availability** on each node
3. **Executes master playbook** (`../ansible/install-master.yml`)
4. **Executes worker playbooks** (`../ansible/install-workers.yml`) 
5. **Worker nodes join the cluster** using tokens from master

Ansible playbooks take care of:
- Installing packages (k3s, dependencies)
- Distributing SSH keys for inter-node communication
- Initializing K3s master
- Joining worker nodes with the correct tokens
- Shell configuration (zsh with antigen)

## Step 4: Cluster Access

After successful deployment, access your K3s cluster.

### 4.1 Getting Cluster Information

```bash
# Navigate to terraform directory
cd terrafrom/

# View all deployment outputs
terraform output
```

### 4.2 Copying Kubeconfig

```bash
# Get the command for copying kubeconfig
terraform output kubeconfig_command

# Execute the displayed scp command (example):
# scp -i ~/.ssh/id_ed25519 root@<master-ip>:~/.kube/config ./kubeconfig
```

### 4.3 Testing Cluster Connectivity

```bash
# Test cluster access
kubectl --kubeconfig ./kubeconfig get nodes
```

**Expected output:**
```bash
NAME         STATUS   ROLES                  AGE   VERSION
kube-master   Ready    control-plane,master   5m    v1.27.5+k3s1
kube-worker-1 Ready    <none>                 4m    v1.27.5+k3s1
kube-worker-2 Ready    <none>                 4m    v1.27.5+k3s1
```

### 4.4 SSH Access to Nodes

```bash
# SSH to master node
ssh -i ~/.ssh/id_ed25519 root@<master-ip>

# SSH to worker nodes
ssh -i ~/.ssh/id_ed25519 root@<worker-1-ip>
ssh -i ~/.ssh/id_ed25519 root@<worker-2-ip>
```

## Step 5: Testing the Cluster

Validate the functionality of your K3s cluster with a comprehensive test application.

### 5.1 Deploying the Test Application

```bash
# Navigate to helm directory
cd ../helm/

# Deploy test application
./deploy-test-app.sh
```

**What the test application provides:**
- ✅ **3 nginx replicas** with customized content
- ✅ **NodePort service** for direct IP access
- ✅ **Load balancing** between worker nodes
- ✅ **Automated tests** for connectivity verification
- ✅ **Real-time monitoring** of cluster status

### 5.2 Accessing the Test Application

**Direct IP access (Recommended):**
```bash
# Access via NodePort on master IP
http://<master-ip>:30080
```

**Port Forward (Alternative):**
```bash
kubectl port-forward -n k3s-test svc/k3s-test-app 8080:80
# Visit: http://localhost:8080
```

### 5.3 What the Test Validates

The test application confirms:
- 🚀 **Container Runtime** - containerd pulling and executing images
- 🌎 **Service Discovery** - Internal DNS and service mesh
- ⚖️ **Load Balancing** - Traffic distribution between pods
- 🔗 **Networking** - Pod-to-pod and external communication
- 📦 **ConfigMaps** - Configuration injection and mounting
- 🔍 **Health Checks** - Liveness and readiness probes

### 5.4 Test Monitoring

```bash
# Check pods across nodes
kubectl get pods -n k3s-test -o wide

# View service details
kubectl get svc -n k3s-test

# Watch logs
kubectl logs -n k3s-test -l app.kubernetes.io/name=k3s-test-app -f
```

## Step 6: Cleanup (Optional)

When you have finished testing or want to remove resources.

### 6.1 Cleaning Up the Test Application

**Automated cleanup (Recommended):**
```bash
# From the helm directory
./destroy-test-app.sh
```

**Manual cleanup:**
```bash
helm uninstall k3s-test-app -n k3s-test
kubectl delete namespace k3s-test
```

### 6.2 Destroying the Infrastructure

**Automated destruction (Recommended):**
```bash
# Return to the project root directory
cd ..

# Run the destruction script
./destroy.sh
```

**Manual destruction:**
```bash
cd terrafrom/
terraform plan -destroy
terraform destroy
```

⚠️ **Warning**: This will permanently delete all servers, data, and configurations!

---

## Advanced Topics

### SSH Access

Connecting to cluster nodes using the generated SSH keys:

```bash
# Master node
ssh -i ~/.ssh/id_ed25519 root@<master-ip>

# Worker nodes  
ssh -i ~/.ssh/id_ed25519 root@<worker-1-ip>
ssh -i ~/.ssh/id_ed25519 root@<worker-2-ip>
```

## Testing the Cluster with Nginx

Test your cluster by deploying a simple Nginx service:

```bash
# Create nginx deployment
kubectl --kubeconfig ./kubeconfig create deployment nginx --image=nginx

# Expose as NodePort service
kubectl --kubeconfig ./kubeconfig expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl --kubeconfig ./kubeconfig get services
```

Access the service using the IP address of any node and the assigned NodePort.

## Security Features

- **SSH key-based authentication** - no password access
- **Inter-node communication** through dedicated SSH keys
- **Private network isolation** - cluster on a dedicated subnet
- **Protection of sensitive variables** - marked as sensitive in Terraform

### Security Best Practices

- Store sensitive values in environment variables:
```bash
export TF_VAR_hcloud_token="your-hetzner-cloud-api-token"
```

- Consider HashiCorp Vault for secrets management in production
- Implement network segmentation and firewalls
- Regular security updates through Ansible automation

## Advanced Configuration

### Remote State Backend

For production use, configure remote state storage:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state"
    key    = "k3s-cluster/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### High Availability // TODO : Add load balancer configuration

Scaling master nodes for high availability:

```hcl
# In terraform.tfvars
master_count = 3
```

### Custom K3s Configuration

Modify Ansible playbooks to customize K3s:
- Adding custom registries
- Configuring storage classes
- Installing additional components

## Troubleshooting

### Common Issues

**SSH Connection Errors:**
- Verify SSH keys are properly configured
- Check network connectivity to servers
- Ensure servers are running and accessible

**Terraform State Locks:**
```bash
# Only if absolutely necessary
terraform apply -lock=false
```

**Ansible Playbook Errors:**
- Add verbose output: `ansible-playbook -vvv`
- Check SSH access manually
- Check sudo permissions

**K3s Joining Errors:**
- Verify token availability on the master
- Check network connectivity on port 6443
- Review k3s logs: `journalctl -u k3s`

### Debugging Commands

```bash
# Terraform debugging
terraform apply -debug

# Check server status in Hetzner Cloud
hcloud server list

# Test SSH connectivity
ssh -o ConnectTimeout=5 -i ~/.ssh/id_ed25519 root@<server-ip> 'echo "Connection successful"'

# K3s cluster status
kubectl --kubeconfig ./kubeconfig cluster-info
kubectl --kubeconfig ./kubeconfig get nodes -o wide
```

## Project Structure

```
├── README.md                    # This documentation
├── ansible/                     # Ansible configuration
│   ├── ansible.cfg             # Ansible settings
│   ├── install-master.yml      # Master node playbook
│   ├── install-workers.yml     # Worker nodes playbook
│   ├── keys/                   # SSH keys for inter-node communication
│   │   ├── k3s_cluster_key     # Private key (600 permissions)
│   │   └── k3s_cluster_key.pub # Public key
│   └── templates/
│       └── zshrc.j2           # Shell configuration template
├── deploy.sh                    # Automated deployment script
├── destroy.sh                   # Automated destruction script
├── helm/                        # Helm configuration for testing
│   ├── Chart.yaml              # Helm chart metadata
│   ├── deploy-test-app.sh      # Script for deploying test application
│   ├── destroy-test-app.sh     # Script for removing test application
│   ├── templates/              # Templates for Kubernetes resources
│   ├── values-ip-access.yaml   # Values for IP access
│   └── values.yaml             # Core values
└── terrafrom/                   # Terraform configuration
    ├── Makefile                # Automation helpers
    ├── kube-clustar.tf         # Server resources and Ansible integration
    ├── lb.tf                   # Load balancer configuration
    ├── main.tf                 # Core configuration
    ├── network.tf              # Network configuration
    ├── output.tf               # Useful outputs
    ├── terraform.tfvars        # Environment configuration
    ├── variables.tf            # Variable definitions
    └── versions.tf             # Provider configuration