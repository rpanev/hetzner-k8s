#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if we are connected to a Kubernetes cluster
print_message "Checking connection to Kubernetes cluster..."
if ! kubectl cluster-info &> /dev/null; then
  print_error "Not connected to a Kubernetes cluster. Please check your kubeconfig."
  exit 1
fi
print_success "Successfully connected to Kubernetes cluster."

# Check if hcloud CLI is installed
HCLOUD_INSTALLED=false
if command -v hcloud &> /dev/null; then
  HCLOUD_INSTALLED=true
  print_success "Hetzner Cloud CLI (hcloud) is installed."
else
  print_warning "Hetzner Cloud CLI (hcloud) is not installed. Will use Kubernetes LoadBalancer IP."
fi

# Define namespace
NAMESPACE="lb-demo"

# Create namespace if it doesn't exist
print_message "Creating namespace $NAMESPACE if it doesn't exist..."
kubectl create namespace $NAMESPACE 2>/dev/null || true
print_success "Namespace $NAMESPACE is ready."

# Step 1: Create ConfigMap for nginx configuration
print_message "Creating ConfigMap for nginx configuration..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: $NAMESPACE
data:
  nginx.conf: |
    server {
      listen 80;
      server_name localhost;
      
      location / {
        root /usr/share/nginx/html;
        index index.html;
      }
      
      location /hostname {
        default_type text/plain;
        proxy_pass http://localhost:8080/hostname;
        proxy_set_header Host \$host;
        add_header Cache-Control no-cache;
      }
      
      location /pod-ip {
        default_type text/plain;
        proxy_pass http://localhost:8080/pod-ip;
        proxy_set_header Host \$host;
        add_header Cache-Control no-cache;
      }
      
      location /node {
        default_type text/plain;
        proxy_pass http://localhost:8080/node;
        proxy_set_header Host \$host;
        add_header Cache-Control no-cache;
      }
      
      location /lb-ip {
        default_type text/plain;
        proxy_pass http://localhost:8080/lb-ip;
        proxy_set_header Host \$host;
        add_header Cache-Control no-cache;
      }
    }
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <title>K3s on Hetzner Cloud with LoadBalancer</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          margin: 40px;
          line-height: 1.6;
          color: #333;
        }
        h1 {
          color: #0066cc;
        }
        .container {
          max-width: 800px;
          margin: 0 auto;
          padding: 20px;
          border: 1px solid #ddd;
          border-radius: 5px;
          box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        .info-box {
          background-color: #f9f9f9;
          padding: 15px;
          margin-bottom: 20px;
          border-radius: 5px;
        }
        .info-item {
          margin-bottom: 10px;
          display: flex;
        }
        .info-label {
          font-weight: bold;
          width: 180px;
        }
        .info-value {
          flex-grow: 1;
        }
        .loading {
          color: #999;
          font-style: italic;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>K3s on Hetzner Cloud Demo</h1>
        <p>This demo shows a simple NGINX server deployed on K3s running on Hetzner Cloud with LoadBalancer.</p>
        
        <div class="info-box">
          <h2>Server Information</h2>
          
          <div class="info-item">
            <div class="info-label">Pod Hostname:</div>
            <div class="info-value" id="hostname"><span class="loading">Loading...</span></div>
          </div>
          
          <div class="info-item">
            <div class="info-label">Pod IP:</div>
            <div class="info-value" id="pod-ip"><span class="loading">Loading...</span></div>
          </div>
          
          <div class="info-item">
            <div class="info-label">Node Name:</div>
            <div class="info-value" id="node"><span class="loading">Loading...</span></div>
          </div>
          
          <div class="info-item">
            <div class="info-label">LoadBalancer IP:</div>
            <div class="info-value" id="lb-ip"><span class="loading">Loading...</span></div>
          </div>
        </div>
      </div>
      
      <script>
        // Function to fetch data from endpoint
        async function fetchData(endpoint, elementId) {
          try {
            const response = await fetch(endpoint);
            if (response.ok) {
              const data = await response.text();
              document.getElementById(elementId).textContent = data;
            } else {
              document.getElementById(elementId).textContent = "Error: " + response.status;
            }
          } catch (error) {
            document.getElementById(elementId).textContent = "Unavailable";
          }
        }
        
        // Fetch data for all endpoints
        fetchData('/hostname', 'hostname');
        fetchData('/pod-ip', 'pod-ip');
        fetchData('/node', 'node');
        fetchData('/lb-ip', 'lb-ip');
      </script>
    </body>
    </html>
EOF

# Step 2: Create LoadBalancer service
print_message "Creating LoadBalancer service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-service
  namespace: $NAMESPACE
  annotations:
    load-balancer.hetzner.cloud/location: "fsn1"
    load-balancer.hetzner.cloud/use-private-ip: "true"
    load-balancer.hetzner.cloud/disable-private-ingress: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: nginx-lb-demo
EOF

print_success "ConfigMap and LoadBalancer service created."

# Step 3: Wait for LoadBalancer to get external IP address
print_message "Waiting for external IP address for LoadBalancer..."
ATTEMPTS=0
MAX_ATTEMPTS=30
EXTERNAL_IP=""
HCLOUD_LB_IP=""

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  EXTERNAL_IP=$(kubectl get svc nginx-lb-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  
  if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "<pending>" ]; then
    break
  fi
  
  ATTEMPTS=$((ATTEMPTS + 1))
  echo -n "."
  sleep 5
done

echo ""

if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "<pending>" ]; then
  # Try to get the real Hetzner Cloud LoadBalancer IP if hcloud CLI is installed
  if [ "$HCLOUD_INSTALLED" = true ]; then
    print_message "Getting real Hetzner Cloud LoadBalancer IP..."
    HCLOUD_LB_DATA=$(hcloud load-balancer list 2>/dev/null)
    if [ $? -eq 0 ]; then
      # Extract IP directly from the tabular output
      HCLOUD_LB_IP=$(echo "$HCLOUD_LB_DATA" | grep -v "^ID" | awk '{print $4}' | head -1)
      if [ -n "$HCLOUD_LB_IP" ]; then
        print_success "Hetzner Cloud LoadBalancer real IP address: $HCLOUD_LB_IP"
        print_message "You can access the application at: http://$HCLOUD_LB_IP"
      else
        print_warning "Could not extract Hetzner Cloud LoadBalancer IP from hcloud output."
        print_message "Using Kubernetes LoadBalancer IP: $EXTERNAL_IP"
        print_message "You can access the application at: http://$EXTERNAL_IP"
      fi
    else
      print_warning "Failed to get Hetzner Cloud LoadBalancer data. Using Kubernetes LoadBalancer IP."
      print_message "You can access the application at: http://$EXTERNAL_IP"
    fi
  else
    print_success "LoadBalancer received external IP address: $EXTERNAL_IP"
    print_message "You can access the application at: http://$EXTERNAL_IP"
  fi
else
  print_warning "Could not get external IP address for LoadBalancer within the timeout period."
  print_message "Check the status of the LoadBalancer with the command: kubectl get svc nginx-lb-service -n $NAMESPACE"
fi

# Step 4: Set the LoadBalancer IP for the deployment
if [ -n "$HCLOUD_LB_IP" ]; then
  REAL_LB_IP="$HCLOUD_LB_IP"
else
  REAL_LB_IP="$EXTERNAL_IP"
fi

# Make sure we have a valid IP
if [ -z "$REAL_LB_IP" ] || [ "$REAL_LB_IP" = "<pending>" ]; then
  REAL_LB_IP="Unavailable"
fi

print_message "Using LoadBalancer IP for application: $REAL_LB_IP"

# Step 5: Create deployment with the correct LoadBalancer IP
print_message "Deploying application with LoadBalancer IP: $REAL_LB_IP"

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-lb-demo
  namespace: $NAMESPACE
  labels:
    app: nginx-lb-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-lb-demo
  template:
    metadata:
      labels:
        app: nginx-lb-demo
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: nginx-index
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        - name: nginx-conf
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
      - name: server-info
        image: python:3.9-alpine
        command: ["python", "-c"]
        args:
        - |
          import http.server
          import socketserver
          import os
          import socket
          
          class ServerInfoHandler(http.server.BaseHTTPRequestHandler):
              def _set_headers(self):
                  self.send_response(200)
                  self.send_header('Content-type', 'text/plain')
                  self.send_header('Cache-Control', 'no-cache')
                  self.end_headers()
              
              def do_GET(self):
                  self._set_headers()
                  if self.path == '/hostname':
                      self.wfile.write(socket.gethostname().encode())
                  elif self.path == '/pod-ip':
                      self.wfile.write(socket.gethostbyname(socket.gethostname()).encode())
                  elif self.path == '/node':
                      self.wfile.write(os.environ.get('NODE_NAME', 'unknown').encode())
                  elif self.path == '/lb-ip':
                      self.wfile.write(os.environ.get('LB_IP', 'unknown').encode())
                  else:
                      self.wfile.write(b'Server Info API')
          
          # Create HTTP server
          handler = ServerInfoHandler
          server = socketserver.TCPServer(('', 8080), handler)
          print('Starting server info HTTP server on port 8080')
          server.serve_forever()
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: LB_IP
          value: "$REAL_LB_IP"
        ports:
        - containerPort: 8080
          name: http
      volumes:
      - name: nginx-index
        configMap:
          name: nginx-config
          items:
          - key: index.html
            path: index.html
      - name: nginx-conf
        configMap:
          name: nginx-config
          items:
          - key: nginx.conf
            path: default.conf
EOF

print_success "Deployment created successfully."

# Step 6: Wait for pods to be ready
print_message "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nginx-lb-demo -n $NAMESPACE --timeout=120s

print_success "Application deployed successfully!"
print_message "You can access the application at: http://$REAL_LB_IP"
print_message "To check the status of the pods, run: kubectl get pods -n $NAMESPACE"
print_message "To check the LoadBalancer service, run: kubectl get svc -n $NAMESPACE"
print_message "To remove the application, run: ./destroy-lb-app.sh"
