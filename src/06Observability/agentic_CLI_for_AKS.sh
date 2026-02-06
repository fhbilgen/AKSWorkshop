# STEP 0: original steps are from https://learn.microsoft.com/en-us/azure/aks/cli-agent-for-aks-install

# STEP 1: Set the environment variables
export CLUSTER_NAME="aksobservedemo"
export RESOURCE_GROUP="aksobservedemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export NODEPOOL_NAME_2="nodepool2"
export VM_SIZE="Standard_D4ds_v5"
export NAMESPACE="default"

# STEP 2: Create a resource group & Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Windows support"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 1 --load-balancer-sku standard --generate-ssh-keys

# Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# STEP 3: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 1 --mode User

# Get AKS cluster credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl apply -f src/06Observability/aks-store-quickstart.yaml 

kubectl get all

# Phase 1: Install the CLI Extension

az extension add --name aks-agent
az extension update --name aks-agent
az aks agent --help


# Phase 2: Choose Your Deployment Mode
# Option B: Cluster Mode (Recommended for SREs)

# Create the Service Account:
kubectl create serviceaccount aks-mcp -n kube-system

# Assign permissions to the Service Account:
kubectl create clusterrole aks-agent-reader \
  --verb=get,list,watch \
  --resource=pods,pods/log,events,nodes,deployments,services,namespaces,configmaps

kubectl create clusterrolebinding aks-agent-reader-binding \
  --clusterrole=aks-agent-reader \
  --serviceaccount=kube-system:aks-mcp

# testing: Answer should be yes!
kubectl auth can-i get pods --as=system:serviceaccount:kube-system:aks-mcp

az aks agent-init --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Select Choice 1: When prompted, choose Cluster Mode.
# Enter Details: Provide the namespace (kube-system) and the service account name (aks-mcp) you created.

# Please choose the LLM provider (1-5): 1
# You selected provider: Azure OpenAI
# Enter value for deployment_name:  (Hint: ensure your deployment name is the same as the model name, e.g., gpt-5) gpt-5.2-chat
# Enter value for api_key: 6Uc...l44a
# Enter value for api_base:  (Hint: https://{azure-openai-service-name}.openai.azure.com/) https://faikbilgen-0128-resource.openai.azure.com/
# Enter value for api_version:  (Default: 2025-04-01-preview) 2024-12-01-preview

az aks agent "How many nodes are in my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
az aks agent "What is the Kubernetes version on the cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
az aks agent "Why is coredns not working on my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
az aks agent "Why is my cluster in a failed state?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE

# metrics reading permissions
kubectl create clusterrole system:metrics-reader --verb=get,list --resource=pods.metrics.k8s.io,nodes.metrics.k8s.io
kubectl create clusterrolebinding aks-mcp-metrics --clusterrole=system:metrics-reader --serviceaccount=kube-system:aks-mcp
kubectl auth can-i list pods.metrics.k8s.io --as=system:serviceaccount:kube-system:aks-mcp --all-namespaces