# STEP 1: Set the environment variables and create an AKS cluster
export CLUSTER_NAME="aksnetworkdemoazcnipodsubnet"
export RESOURCE_GROUP="aksnetworkdemoazcnipodsubnet-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_B4pls_v2"
export VNET_NAME="myVirtualNetwork"
export SUBNET_NAME_1="nodesubnet"
export SUBNET_NAME_2="podsubnet"
export SUBSCRIPTION=$(az account show --query id -o tsv)

# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create the two subnet network 
az network vnet create --resource-group $RESOURCE_GROUP --location $LOCATION --name $VNET_NAME --address-prefixes 10.0.0.0/8 -o none 
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME_1 --address-prefixes 10.240.0.0/16 -o none 
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME_2 --address-prefixes 10.241.0.0/16 -o none

echo "Create a cluster with Azure CNI networking Pod Subnet"
az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --max-pods 250 --node-count 2 --network-plugin azure --vnet-subnet-id /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME_1 --pod-subnet-id /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME_2 --enable-addons monitoring --generate-ssh-keys


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
