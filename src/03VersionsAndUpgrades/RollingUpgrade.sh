# STEP 1

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
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --vm-set-type VirtualMachineScaleSets --kubernetes-version 1.33.0 --node-count 2 --os-sku Ubuntu --location $LOCATION --load-balancer-sku standard --network-plugin azure --windows-admin-username $WINDOWS_ADMIN_USERNAME --windows-admin-password $WINDOWS_ADMIN_PASSWORD --generate-ssh-keys

#Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# STEP 2: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

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

# Try to upgrade the node pool to 1.33.3
# Observe that it fails because the control plane is at 1.33.2
az aks nodepool upgrade --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --kubernetes-version 1.33.3

# An error similar to the following one can be observed:

# (NodePoolMcVersionIncompatible) Node pool version 1.33.3 and control plane version 1.33.2 are incompatible. Patch version of node pool version 3 is bigger than control plane version 2. For more information, please check https://aka.ms/aks/nodepoolmcversionincompatible
# Code: NodePoolMcVersionIncompatible
# Message: Node pool version 1.33.3 and control plane version 1.33.2 are incompatible. Patch version of node pool version 3 is bigger than control plane version 2. For more information, please check https://aka.ms/aks/nodepoolmcversionincompatible

# STEP 5: Upgrade the node pool to 1.33.2
# Let's try upgrading the node pool to 1.33.2
az aks nodepool upgrade --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --kubernetes-version 1.33.2

# In a second window check the pods' distribution
kubectl get pods -o wide --watch

# In a second window check the pods' distribution
kubectl get node -o wide --watch

# In a fourth window
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --query "{provisioningState:provisioningState, powerState:powerState.code}"
az monitor activity-log list --resource-group $RESOURCE_GROUP --query "[?contains(resourceId, '$CLUSTER_NAME')].{Time:eventTimestamp, Status:status.localizedValue, Operation:operationName.localizedValue}" --output table
kubectl get events --all-namespaces --sort-by='.lastTimestamp' --watch
kubectl get events -A --field-selector involvedObject.kind=Node --watch
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --query "[].{Name:name, State:provisioningState, OrchestratorVersion:orchestratorVersion}" --output table


# STEP 6: Clean-up

# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait