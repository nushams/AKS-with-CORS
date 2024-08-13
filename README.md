# AKS with CORS proxy

## Overview

This document outlines the steps to create and set up a test account on Microsoft Azure, a subscription, resource group, AKS cluster and CORS proxy.

## Steps to create a Test Account on Azure

### 1. Sign up for an Azure Account

1. Go to the [Azure Portal](https://portal.azure.com).
2. Click on "Create one!" to set up a new Microsoft account.
3. Follow the prompts to complete the sign-up process.

### 2. Verify your Identity

1. Verify your identity using a phone number and a credit card.
2. Enter your phone number and insert code sent to your phone.
3. Provide your credit card details for account validation.

### 3. Access the Azure Portal

1. Once your account is set up, go to [Azure Portal](https://portal.azure.com) and sign in.

### 4. Create a Subscription

1. Click on the "Subscriptions" link in the left-hand menu. 
2. Click on the "Create" button to start creating a new subscription.
3. Choose the subscription type free trial or a basic subscription is typically sufficient.
4. Follow the on-screen instructions to complete the subscription setup. Ensure you assign a name and any required details.

### 5. Create a Resource Group

1. Navigate to "Resource groups" in the left-hand menu.
2. Click "Create."
3. Enter a name for the resource group (e.g., `AKSwithCORS-RG`).
4. Select a region close to your location.
5. Click "Review + create" and then "Create."

# Kubernetes Cluster Setup on AKS (Azure)

### 1. Prerequisites

1. **Azure CLI**: Ensure the Azure CLI is installed. You can download it from the [official site](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
2. **kubectl**: Install `kubectl`, the Kubernetes command-line tool. Instructions can be found [here](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

### 2. Create an AKS Cluster
Create the AKS cluster with high availability (availability zones enabled) and auto-scaling enabled:
```bash
az aks create \
  --resource-group AKSwithCORS-RG \
  --name AKS-Cluster \
  --node-count 3 \
  --enable-addons monitoring \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5 \
  --zones 1 2 3 \
  --generate-ssh-keys
```

- `--node-count 3`: Initial number of nodes in the cluster.
- `--enable-addons monitoring`: Enables monitoring with Azure Monitor.
- `--enable-cluster-autoscaler`: Enables automatic scaling of nodes.
- `--min-count 1`: Minimum number of nodes.
- `--max-count 5`: Maximum number of nodes.

### 3. Configure kubectl
1. Get the credentials for your AKS cluster:
```bash
az aks get-credentials --resource-group AKSwithCORS-RG --name AKS-Cluster
```
2. Verify that you can access the cluster:
```bash
kubectl get nodes
```

### 4. Configure High Availability
1. Pod Disruption Budgets: Set up Pod Disruption Budgets to ensure that your applications remain highly available during voluntary disruptions.

Example YAML for a Pod Disruption Budget:
```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: akscors
```

### 5. Set Up Horizontal Pod Autoscaling
Deploy an application with CPU resource requests and limits.

Create an Horizontal Pod Autoscaler:
```bash
kubectl autoscale deployment akscors --cpu-percent=50 --min=1 --max=10
```
- `--cpu-percent=50`: Target average CPU utilization.
- `--min=1`: Minimum number of pods.
- `--max=10`: Maximum number of pods.

# Infrastructure as Code using Terraform
## Prerequisites 
- Terraform: Install Terraform from [here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
- Azure CLI: Ensure Azure CLI is installed and configured.

## Terraform Configuration Files
Create the following Terraform configuration files:

`main.tf`
```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "example" {
  name                = "AKSVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "AKSSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "AKS-Cluster"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_DS2_v2"
    os_type    = "Linux"

    availability_zones = ["1", "2", "3"]
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "testing"
  }
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.example.kube_config[0].raw_kube_config
}
```

`variables.tf`
```hcl
variable "location" {
  description = "The Azure location where resources will be created."
  default     = "North Europe"
}

variable "resource_group_name" {
  description = "The name of the Azure Resource Group."
  default     = "AKSwithCORS-RG"
}
```

`outputs.tf`
```hcl
output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.example.name
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.example.name
}

output "location" {
  description = "The Azure location where resources are created."
  value       = azurerm_resource_group.example.location
}
```

## Steps to use Terraform
1. Initialize the Terraform configuration:
```bash
terraform init
```
2. Generate an execution plan:
```bash
terraform plan
```
3. Apply the Terraform configuration to create the resources:
```bash
terraform apply
```

# Application Deployment: Simple CORS Proxy
## Deploying the CORS Proxy

1. Clone the CORS Proxy Repository:
```bash
git clone https://github.com/Rob--W/cors-anywhere
cd cors-anywhere
```
2. Create a Dockerfile for Kubernetes Deployment:
```docker
FROM node:14
WORKDIR /usr/src/app
COPY . .
RUN npm install
EXPOSE 8080
CMD ["node", "server.js"]
```
3. Build and Push the Docker Image:
```bash
docker build -t <your-dockerhub-username>/cors-proxy .
# then
docker push <your-dockerhub-username>/cors-proxy
```
4. Create a Kubernetes Deployment YAML:
```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: cors-proxy
     namespace: AKS-Cluster
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: cors-proxy
     template:
       metadata:
         labels:
           app: cors-proxy
       spec:
         containers:
         - name: cors-proxy
           image: <your-dockerhub-username>/cors-proxy
           ports:
           - containerPort: 8080
           resources:
             requests:
               memory: "128Mi"
               cpu: "250m"
             limits:
               memory: "256Mi"
               cpu: "500m"
```
5. Create a Kubernetes Service YAML:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cors-proxy-service
  namespace: AKS-Cluster
spec:
  type: LoadBalancer
  selector:
    app: cors-proxy
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

6. Apply the Deployment and Service:
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```
7. Retrieve the External IP Address:
```bash
kubectl get svc cors-proxy-service
```
8. Test the CORS Proxy:
```bash
curl -H "Origin: http://X.com" --verbose http://<EXTERNAL-IP>/http://www.google.com
```
- `http://X.com` is your URL.
- `EXTERNAL-IP` is coming from the step 7.

If successful, the proxy should return the Google homepage with the appropriate CORS headers.

# Scalability: Auto-Scaling the CORS Proxy Service on AKS and Load Testing

## Steps to Configure Auto-Scaling for CORS Proxy

### 1. Create a Horizontal Pod Autoscaler (HPA):
```bash
kubectl autoscale deployment cors-proxy --cpu-percent=50 --min=2 --max=10
```

2. Verify the Metrics Server is running:
```bash
kubectl get deployment metrics-server -n kube-system
```
### 2. Configure Ingress and Load Balancing
To handle up to 1000 requests per second, ensure that your ingress and load balancing are correctly configured.

### 3. Load Testing and Scaling Verification
To ensure the service can handle 1000 requests per second, perform load testing.
- Use a benchmarking tool (e.g., Apache Benchmark, wrk) to estimate the CPU and memory usage per request.
- For example, run a benchmark locally to simulate 1000 requests per second.
```bash
ab -n 1000 -c 100 http://<EXTERNAL-IP>/
```
- Monitor the CPU/memory usage and configure the HPA to scale up when reaching a threshold.

## Optimize and Scale Further if Needed
1. Tweak HPA Settings:

- Based on the results of your load testing, you may need to adjust the HPA configuration. For example, lowering the --cpu-percent threshold may trigger scaling sooner under load.
2. Increase Node Pool Size:

- If the service requires more pods than your current nodes can support, consider increasing the size of your AKS node pool or adding more nodes.
```bash
az aks scale --resource-group AKSwithCORS-RG --name AKS-Cluster --node-count <desired-node-count>
```
3. Advanced Scaling Techniques:

- Consider using Cluster Autoscaler if your Kubernetes nodes themselves need to scale based on load. This automatically adds or removes nodes from your cluster depending on the resource demands.
```bash
az aks update --resource-group AKSwithCORS-RG --name AKS-Cluster --enable-cluster-autoscaler --min-count 3 --max-count 10
```
- Increase HPA Limits: Adjust the HPA to allow scaling beyond the initial limits if necessary.
```bash
kubectl autoscale deployment cors-proxy --cpu-percent=50 --min=2 --max=20
```
#### For extremely high traffic (e.g., 10,000+ requests per second), consider using multiple AKS clusters spread across different regions. You can use Azure Traffic Manager or a similar service to distribute the traffic between these clusters. The main challenge and limitations can be due to max pod count and node capacity, additionally, due to overall network latency.