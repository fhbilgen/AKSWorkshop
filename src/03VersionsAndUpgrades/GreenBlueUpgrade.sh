# STEP 1: Set up environment variables and create the AKS cluster 

# Set the environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME_BLUE="bluenodepool"
export NODEPOOL_NAME_GREEN="greennodepool"
export NODEPOOL_NAME_WINDOWS="winpol"
export VM_SIZE="Standard_D4ds_v5"
export WINDOWS_ADMIN_USERNAME="azureuser"
export WINDOWS_ADMIN_PASSWORD="P@ssw0rd1234?xE5r"


# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Windows support"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --vm-set-type VirtualMachineScaleSets --kubernetes-version 1.33.0 --node-count 2 --os-sku Ubuntu --location $LOCATION --load-balancer-sku standard --network-plugin azure --windows-admin-username $WINDOWS_ADMIN_USERNAME --windows-admin-password $WINDOWS_ADMIN_PASSWORD --generate-ssh-keys

#Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# STEP 2: Add the BLUE node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_BLUE --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

echo "Check the status of the node pools in the AKS cluster"
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME

# STEP 3
###########################################################
###   Deploy the pods and check their distribution      ###
###   They should be running only on the user node pool ###
###########################################################

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl apply -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml

kubectl get pods -o wide


# STEP 4: Check for available upgrades for the AKS cluster

echo "Checking for available upgrades for the AKS cluster"
az aks get-upgrades --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME


#Upgrade the control plane to 1.33.2
az aks upgrade --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --control-plane-only --kubernetes-version 1.33.2

# Meanwhile in a second window check the execution of the pods
kubectl get pods -o wide

# STEP 5:
# Add the GREEN node pool with kubernetes version 1.33.2
echo "Adding the green node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_GREEN --node-vm-size $VM_SIZE --kubernetes-version 1.33.2 --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

echo "Check the status of the node pools in the AKS cluster"
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME


# STEP 6: Cordon blue nodes
kubectl get nodes -o wide
kubectl cordon <blue-node-1>
kubectl cordon <blue-node-2>

# STEP 7: Drain blue nodes
kubectl drain <blue-node-1> --ignore-daemonsets --delete-emptydir-data
kubectl drain <blue-node-2> --ignore-daemonsets --delete-emptydir-data

# STEP 8: Check the pods and make sure all of the pods are running on the green node pool and blue nodes are cordoned and drained
kubectl get pods -o wide
kubectl get node -o wide

# STEP 9A:  Commit - Delete blue node pool 
az aks nodepool delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name $NODEPOOL_NAME_BLUE

# STEP 9B: Roll back - Return to blue nodes
kubectl uncordon <blue-node-1>
kubectl uncordon <blue-node-2>
kubectl drain <green-node-1> --ignore-daemonsets --delete-emptydir-data
kubectl drain <green-node-2> --ignore-daemonsets --delete-emptydir-data
az aks nodepool delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name $NODEPOOL_NAME_GREEN


# STEP 10: Clean up

# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait