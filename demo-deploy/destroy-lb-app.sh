#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# Function to display messages
print_message() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to display errors
print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display success
print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display warnings
print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  print_error "kubectl is not installed. Please install it before continuing."
  exit 1
fi

# Check connection to Kubernetes cluster
print_message "Checking connection to Kubernetes cluster..."
if ! kubectl cluster-info &> /dev/null; then
  print_error "Cannot establish connection to Kubernetes cluster. Please check your configuration."
  exit 1
fi

print_success "Successfully connected to Kubernetes cluster."

# Namespace for the application
NAMESPACE="lb-demo"

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
  print_warning "Namespace $NAMESPACE does not exist. Nothing to remove."
  exit 0
fi

# Display information about resources before removal
print_message "Current resources in namespace $NAMESPACE before removal:"
echo ""
echo "Services:"
kubectl get services -n $NAMESPACE
echo ""
echo "Deployments:"
kubectl get deployments -n $NAMESPACE
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE
echo ""

# Save LoadBalancer IP address for information
LB_IP=$(kubectl get svc nginx-lb-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

# User confirmation
read -p "Are you sure you want to remove all resources in namespace $NAMESPACE? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  print_message "Operation cancelled."
  exit 0
fi

# Remove Service with type LoadBalancer first
print_message "Removing LoadBalancer Service..."
kubectl delete service nginx-lb-service -n $NAMESPACE

# Wait for LoadBalancer to be removed
print_message "Waiting for LoadBalancer to be removed from Hetzner Cloud..."
ATTEMPTS=0
MAX_ATTEMPTS=20

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if ! kubectl get service nginx-lb-service -n $NAMESPACE &> /dev/null; then
    break
  fi
  
  ATTEMPTS=$((ATTEMPTS + 1))
  echo -n "."
  sleep 3
done

echo ""
print_success "LoadBalancer Service has been removed."

# Remove remaining resources
print_message "Removing remaining resources..."
kubectl delete deployment nginx-lb-demo -n $NAMESPACE
kubectl delete configmap nginx-config -n $NAMESPACE

# Remove namespace
print_message "Removing namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE

# Check if namespace is removed
ATTEMPTS=0
MAX_ATTEMPTS=10

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    break
  fi
  
  ATTEMPTS=$((ATTEMPTS + 1))
  echo -n "."
  sleep 2
done

echo ""

if ! kubectl get namespace $NAMESPACE &> /dev/null; then
  print_success "Namespace $NAMESPACE has been successfully removed."
else
  print_warning "Namespace $NAMESPACE still exists. It may take a bit more time for complete removal."
fi

if [ -n "$LB_IP" ]; then
  print_message "LoadBalancer with IP address $LB_IP has been removed from Hetzner Cloud."
fi

print_success "All resources have been successfully removed."
print_message "To deploy the application again, use the script: ./deploy-lb-app.sh"
