#!/bin/bash

# K3s Hetzner Cloud Cluster Deployment Script
# This script automates the Terraform deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required files exist
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if we're in the project root directory
    if [[ ! -f "terrafrom/main.tf" ]]; then
        print_error "terrafrom/main.tf not found. Please run this script from the project root directory."
        exit 1
    fi

    # Check if ansible directory exists
    if [[ ! -d "ansible" ]]; then
        print_warning "ansible directory not found. Creating it..."
        mkdir -p ansible/playbooks
        print_success "Created ansible directory structure"
    fi

    # Check if terraform.tfvars exists
    if [[ ! -f "terrafrom/terraform.tfvars" ]]; then
        print_error "terrafrom/terraform.tfvars not found. Please create and configure it first."
        exit 1
    fi

    # Check if hcloud CLI is installed and configured
    if ! command -v hcloud &> /dev/null; then
        print_warning "hcloud CLI not found. Checking for token in terraform.tfvars..."
        if ! grep -q 'hcloud_token' "terrafrom/terraform.tfvars"; then
            print_error "Hetzner Cloud API token not found. Either install hcloud CLI or add token to terrafrom/terraform.tfvars."
            echo "  Option 1: Install hcloud CLI and configure it with your token"
            echo "  Option 2: Add your Hetzner Cloud API token to terrafrom/terraform.tfvars:"
            echo "           hcloud_token = \"your-token-here\""
            exit 1
        fi
    else
        print_success "hcloud CLI found. Will use its configuration for authentication."
        # Export the token from hcloud config to be used by Terraform
        HCLOUD_TOKEN=$(grep -o 'token .*' ~/.config/hcloud/cli.toml 2>/dev/null | cut -d' ' -f2 | tr -d '"' || echo '')
        if [[ -z "$HCLOUD_TOKEN" ]]; then
            print_warning "Could not extract token from hcloud config. Will rely on terraform.tfvars or environment variables."
        else
            print_success "Successfully extracted token from hcloud config."
            # Add token to terraform.tfvars if it doesn't exist
            if ! grep -q 'hcloud_token' "terrafrom/terraform.tfvars"; then
                echo "\nhcloud_token = \"$HCLOUD_TOKEN\"" >> "terrafrom/terraform.tfvars"
                print_success "Added hcloud token to terraform.tfvars"
            fi
        fi
    fi

    # Check if SSH key is configured
    if ! grep -q 'ssh_key_fingerprint' "terrafrom/terraform.tfvars"; then
        print_error "SSH key fingerprint not found in terrafrom/terraform.tfvars."
        echo "  Please add your SSH key fingerprint to terrafrom/terraform.tfvars:"
        echo "  ssh_key_fingerprint = \"your-ssh-key-fingerprint\""
        exit 1
    fi

    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi

    # Check if Ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed. Please install it first."
        exit 1
    fi

    print_success "Prerequisites check passed!"
}

# Function to show deployment summary
show_summary() {
    print_status "Deployment Summary:"
    echo "===================="

    # Extract key values from terraform.tfvars
    if [[ -f "terrafrom/terraform.tfvars" ]]; then
        echo "Image: $(grep '^image' terrafrom/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo 'Not specified')"
        echo "Server Type: $(grep '^server_type' terrafrom/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo 'Not specified')"
        echo "Datacenter: $(grep '^datacenter' terrafrom/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo 'Not specified')"
        echo "Network: $(grep '^ip_range' terrafrom/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo 'Not specified')"
        echo "Subnet: $(grep '^subnet_ip_cidr' terrafrom/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo 'Not specified')"
        echo "Worker Count: $(grep '^worker_count' terrafrom/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo '2')"
    fi
    echo "===================="
    echo
}

# Main deployment function
deploy_cluster() {
    print_status "Starting K3s Hetzner Cloud cluster deployment..."
    echo

    # Change to terraform directory
    cd terrafrom || {
        print_error "Failed to change to terrafrom directory!"
        exit 1
    }

    # Step 1: Terraform Init
    print_status "Step 1/4: Initializing Terraform..."
    if terraform init; then
        print_success "Terraform initialization completed!"
    else
        print_error "Terraform initialization failed!"
        cd ..
        exit 1
    fi
    echo

    # Step 2: Terraform Validate
    print_status "Step 2/4: Validating Terraform configuration..."
    if terraform validate; then
        print_success "Terraform validation passed!"
    else
        print_error "Terraform validation failed!"
        cd ..
        exit 1
    fi
    echo

    # Step 3: Terraform Plan
    print_status "Step 3/4: Creating Terraform execution plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan created successfully!"
    else
        print_error "Terraform plan failed!"
        cd ..
        exit 1
    fi
    echo

    # Ask for confirmation before apply
    print_warning "Ready to deploy the K3s cluster. This will:"
    echo "  • Create servers on Hetzner Cloud"
    echo "  • Configure private networking"
    echo "  • Install and configure K3s cluster"
    echo "  • Set up SSH access and security"
    echo
    read -p "Do you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_warning "Deployment cancelled by user."
        rm -f tfplan
        cd ..
        exit 0
    fi

    # Step 4: Terraform Apply
    print_status "Step 4/4: Applying Terraform configuration..."
    echo "This may take 10-15 minutes depending on your environment..."
    echo

    if terraform apply tfplan; then
        print_success "Terraform deployment completed successfully!"
        rm -f tfplan
    else
        print_error "Terraform deployment failed!"
        rm -f tfplan
        cd ..
        exit 1
    fi

    # Return to project root
    cd ..
}

# Function to show post-deployment instructions
show_post_deployment() {
    echo
    print_success "K3s Cluster Deployment Complete!"
    echo
    print_status "Next steps:"
    echo "1. Get cluster access information:"
    echo "   cd terrafrom && terraform output"
    echo
    echo "2. SSH to master node:"
    echo "   ssh root@\$(cd terrafrom && terraform output -raw master_public_ip)"
    echo
    echo "3. Get kubeconfig from master node:"
    echo "   scp root@\$(cd terrafrom && terraform output -raw master_public_ip):/etc/rancher/k3s/k3s.yaml ./kubeconfig"
    echo "   sed -i '' 's/127.0.0.1/'\$(cd terrafrom && terraform output -raw master_public_ip)'/g' ./kubeconfig"
    echo
    echo "4. Test cluster connectivity:"
    echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
    echo "   kubectl get nodes"
    echo
    print_status "For troubleshooting, check the README.md file."
}

# Function to handle cleanup on script interruption
cleanup() {
    print_warning "Script interrupted. Cleaning up..."
    rm -f terrafrom/tfplan
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main script execution
main() {
    echo "=================================================="
    echo "    K3s Hetzner Cloud Cluster Deployment Script"
    echo "=================================================="
    echo

    check_prerequisites
    show_summary
    deploy_cluster
    show_post_deployment
}

# Run main function
main "$@"