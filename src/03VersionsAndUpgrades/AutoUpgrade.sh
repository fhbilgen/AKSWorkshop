# STEP: 1

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

# STEP: 2
# Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

echo "Check the status of the node pools in the AKS cluster"
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME

# STEP: 3
###########################################################
###   Deploy the pods and check their distribution      ###
###   They should be running only on the user node pool ###
###########################################################

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl apply -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml

kubectl get pods -o wide


# STEP 4: check the auto upgrade profile
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "autoUpgradeProfile"

# The default values should appear
# {
#   "nodeOsUpgradeChannel": "NodeImage",
#   "upgradeChannel": null
# }

# STEP 5: Set the auto upgrade channel to STABLE and node-os-upgrade channel to SecurityPatch


az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --auto-upgrade-channel stable
# Now the profile should be like:
# {
#   "nodeOsUpgradeChannel": "NodeImage",
#   "upgradeChannel": "stable"
# }

az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-os-upgrade-channel SecurityPatch
# Now:
# {
#   "nodeOsUpgradeChannel": "SecurityPatch",
#   "upgradeChannel": "stable"
# }


# STEP 6:Add maintenance windows

# Add a new aksManagedAutoUpgradeSchedule and aksManagedNodeOSUpgradeSchedule configuration
az aks maintenanceconfiguration add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name aksManagedAutoUpgradeSchedule --schedule-type Weekly --day-of-week Saturday --interval-weeks 3 --duration 8 --utc-offset +03:00 --start-time 15:00
az aks maintenanceconfiguration add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name aksManagedNodeOSUpgradeSchedule --schedule-type Weekly --day-of-week Saturday --interval-weeks 3 --duration 8 --utc-offset +03:00 --start-time 17:00


# STEP 7: Wait untile the upgrade starts. Allow 10 minutes to start from the sceduled time
kubectl get pods -o wide
kubectl get node -o wide

kubectl get events --field-selector source=upgrader

# STEP: 8

# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait