# STEP 1: Set the environment variables and create an AKS cluster
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export NODEPOOL_NAME_LARGER="mynodepoolxl"
export NODEPOOL_NAME_WINDOWS="winpol"
export VM_SIZE="Standard_D4ds_v5"
export VM_SIZE_LARGER="Standard_D8ds_v5"
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

# STEP 2: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 2 --mode User


# STEP: 3
###########################################################
###   Deploy the pods and check their distribution      ###
###   They should be running only on the user node pool ###
###########################################################

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl apply -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml

kubectl get pods -o wide

# STEP 4: Adding a new node pool to replace the second node pool 
echo "Adding a new node pool with larger VM sizesto replace the second node pool"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_LARGER --node-vm-size $VM_SIZE_LARGER --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

kubectl get nodes -o wide

# STEP 5: Cordon the existing nodes
kubectl cordon aks-mynodepool-39965189-vmss000000  aks-mynodepool-39965189-vmss000001

kubectl get nodes -o wide

kubectl get pod -o wide

# STEP 6: Drain the existing nodes
kubectl drain aks-mynodepool-39965189-vmss000000  aks-mynodepool-39965189-vmss000001 --ignore-daemonsets --delete-emptydir-data

kubectl get pods -o wide -A

# STEP 7: Remove the existing node pool
az aks nodepool delete --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME

kubectl get nodes -o wide

kubectl get pod -o wide

# STEP : Cleanup
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait