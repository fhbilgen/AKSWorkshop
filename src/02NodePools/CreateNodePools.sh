# Set the environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export NODEPOOL_NAME_WINDOWS="winpol"
export VM_SIZE="Standard_D4ds_v5"
export WINDOWS_ADMIN_USERNAME="azureuser"
export WINDOWS_ADMIN_PASSWORD="P@ssw0rd1234?xE5r"


# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Windows support"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --vm-set-type VirtualMachineScaleSets --node-count 2 --os-sku Ubuntu --location $LOCATION --load-balancer-sku standard --network-plugin azure --windows-admin-username $WINDOWS_ADMIN_USERNAME --windows-admin-password $WINDOWS_ADMIN_PASSWORD --generate-ssh-keys

#Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 3

# Add a Windows Server node pool
# Install the aks-preview extension
echo "Installing the aks-preview extension"
az extension add --name aks-preview
az extension update --name aks-preview

# Register the AksWindows2025Preview feature flag
echo "Register the AksWindows2025Preview feature flag"
az feature register --namespace "Microsoft.ContainerService" --name "AksWindows2025Preview"
az feature show --namespace Microsoft.ContainerService --name AksWindows2025Preview
az provider register --namespace Microsoft.ContainerService


# Create the Windows Server 2025 node pool
# Show details for your node pool
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_WINDOWS --node-vm-size $VM_SIZE --os-type Windows --os-sku Windows2025 --enable-fips-image --node-count 3
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_WINDOWS

echo "Check the status of the node pools in the AKS cluster"
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME


# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait