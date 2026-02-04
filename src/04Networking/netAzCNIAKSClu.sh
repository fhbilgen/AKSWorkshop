# STEP 1: Set the environment variables and create an AKS cluster
export CLUSTER_NAME="aksnetworkdemoazcni"
export RESOURCE_GROUP="aksnetworkdemoazcni-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_B4pls_v2"

# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Azure CNI networking"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 2 --os-sku Ubuntu --location $LOCATION  --network-plugin azure --generate-ssh-keys

# STEP 2: Get the credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# STEP 3: Install the sample application
# This file is published in the repo: https://github.com/Azure-Samples/aks-store-demo
# The CPU request for the store-front container has been modified to 10m from 1m.
kubectl apply -f src/00AKSStoreApp/aks-store-quickstart.yaml 

# STEP 4: Clean up resources
# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait
