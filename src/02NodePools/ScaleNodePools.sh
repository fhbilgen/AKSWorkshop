# STEP 1: Set the environment variables and create an AKS cluster
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
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --vm-set-type VirtualMachineScaleSets --node-count 2 --os-sku Ubuntu --location $LOCATION --load-balancer-sku standard  --windows-admin-username $WINDOWS_ADMIN_USERNAME --windows-admin-password $WINDOWS_ADMIN_PASSWORD --generate-ssh-keys

# Taint the default node pool to prevent user pods from being scheduled on it
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

# STEP 4:  Scale the Linux node pool
echo "Scaling the Linux node pool to 4 nodes"
az aks nodepool scale --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-count 4

kubectl get node -o wide

# Increase the number of pods in the deployment and check their distribution
kubectl scale deployment pod-upgrade --replicas=10

kubectl get pods -o wide

# STEP 5: Drop the deployment and the node pool
kubectl delete -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml
az aks nodepool delete --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME

# STEP 6: Recreate the same node pool and enable cluster autoscaling
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --enable-cluster-autoscaler --min-count 2 --max-count 5

az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --query "maxPods"


# STEP 7: Deploy the pods again and check their distribution
kubectl apply -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml

kubectl get pods -o wide

kubectl scale deployment pod-upgrade --replicas=50

kubectl get pods -o wide

# STEP 8: Check the creation of new nodes in the node pool
# Observe that some pods are in the "PENDING" state until new nodes are created
# NOTE: It may take a few minutes for new nodes to be created
kubectl get nodes -o wide

kubectl get pods -o wide

# STEP 9: Cleanup the cluster
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait