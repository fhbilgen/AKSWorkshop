# STEP 1: Set the environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_D4ds_v5"
export WINDOWS_ADMIN_USERNAME="azureuser"
export WINDOWS_ADMIN_PASSWORD="P@ssw0rd1234?xE5r"

# STEP 2: Create a resource group & Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Windows support"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 1 --load-balancer-sku standard --enable-cluster-autoscaler --min-count 1 --max-count 3 --generate-ssh-keys

# Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# STEP 3: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 1 --mode User


# STEP 4: Deploy the pods and check their distribution.

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl apply -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml

kubectl get pods -o wide

# STEP 5: Connect using kubectl debug

kubectl get nodes -o wide
kubectl debug node/aks-mynodepool-34171003-vmss000000 -it --image=mcr.microsoft.com/cbl-mariner/busybox:2.0

# Execute some commands inside the debug container

# Exit the pod and then delete it
exit
kubectl delete pod node-debugger-aks-mynodepool-34171003-vmss000000-64hv9

# STEP 6: Cleanup the cluster
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait