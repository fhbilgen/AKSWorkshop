# STEP 1: Environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_B4pls_v2"

# IMPORTANT: Choose a region that supports Availability Zones #
# To check the available VMs for zone redundancy in your region, run:
az vm list-skus -l $LOCATION --zone --resource-type virtualMachines -o table > ${LOCATION}vms.txt
 
# Top Regions with Guaranteed 3-Zone Support
#  Geography,Recommended Regions (3 Zones)
# Americas,"East US, East US 2, Central US, South Central US, West US 3"
# Europe,"West Europe, North Europe, France Central, UK South, Germany West Central"
# Asia,"Southeast Asia, East Asia, Japan East, Australia East"

# STEP 2: Create the AKS cluster and the user node pool 
# Create a resource group

echo "Creating the resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create an AKS cluster, and create a zone-spanning system node pool in all three AZs, one node in each AZ
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 3 --zones 1 2 3 --node-vm-size $VM_SIZE
# Taint the default node pool to prevent user pods from being scheduled on it
#Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# Add one new zone-spanning user node pool, two nodes in each
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME  --node-count 6 --node-vm-size $VM_SIZE --zones 1 2 3

# Get AKS cluster credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

kubectl get nodes -o custom-columns='NAME:metadata.name, REGION:metadata.labels.topology\.kubernetes\.io/region, ZONE:metadata.labels.topology\.kubernetes\.io/zone'

# Output similar to 
# NAME                                  REGION    ZONE
# aks-mynodepool-12265658-vmss000000   westus2   westus2-1
# aks-mynodepool-12265658-vmss000001   westus2   westus2-2
# aks-mynodepool-12265658-vmss000002   westus2   westus2-3
# aks-mynodepool-12265658-vmss000003   westus2   westus2-1
# aks-mynodepool-12265658-vmss000004   westus2   westus2-2
# aks-mynodepool-12265658-vmss000005   westus2   westus2-3
# aks-nodepool1-42826202-vmss000000    westus2   westus2-1
# aks-nodepool1-42826202-vmss000001    westus2   westus2-2
# aks-nodepool1-42826202-vmss000002    westus2   westus2-3

# STEP 3: Deploy a sample application that uses zone-spanning deployment
kubectl apply -f src/01AKSBasicsAndSetup/AvZnZoneSpanDeployment.yaml 

# STEP 4: Conduct a Chaos test simulating zone unavailability

# STEP 5: Clean up resources
# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait
