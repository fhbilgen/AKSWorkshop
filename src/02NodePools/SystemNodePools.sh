# Set the environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export USER_NODEPOOL_NAME="userpool"
export SYSTEM_NODEPOOL_NAME="systempool"

# Create a resource group
# Create an AKS cluster with a single system pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Creating AKS cluster with a single system pool"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 2 --generate-ssh-keys


# Add a dedicated system node pool to an existing AKS cluster
echo "Adding a dedicated system node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME --node-count 3 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# Show details for your node pool
echo "Showing details for the system node pool"
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME

# Update existing cluster system and system node pools
echo "Updating system node pool to user node pool"
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME --mode User

echo "Showing details of the node pool"
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME

# Now, although the system node pool is changed to user mode, it still retains its taints !!!
#   "mode": "User",
#   "name": "systempool",
#   "networkProfile": null,
#   "nodeImageVersion": "AKSUbuntu-2204gen2containerd-202512.18.0",
#   "nodeLabels": null,
#   "nodePublicIpPrefixId": null,
#   "nodeTaints": [
#     "CriticalAddonsOnly=true:NoSchedule"
#   ],

# Therefore you need to remove the taints explicitly if you want to use it as a user node pool
echo "Removing taints from the node pool"
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME --node-taints ""


# Update existing cluster system and user node pools
echo "Updating user node pool to system node pool"
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

echo "Showing details of the node pool"
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME

# Delete a system node pool
echo "Deleting the system node pool"
az aks nodepool delete --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $SYSTEM_NODEPOOL_NAME

# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait