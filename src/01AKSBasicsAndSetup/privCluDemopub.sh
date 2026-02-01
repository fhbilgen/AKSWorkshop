# STEP 1: Set the environment variables and create an AKS cluster
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"

# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Windows support"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 1 --os-sku Ubuntu --location $LOCATION --generate-ssh-keys

# STEP: 3
###########################################################
###   Deploy the pods and check their distribution      ###
###   They should be running only on the user node pool ###
###########################################################

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# STEP 4: Get the API Server access information
export CONTROL_PLAN_IP=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query fqdn --output tsv)

ping $CONTROL_PLAN_IP

kubectl cluster-info

# Get the API endpoint address and decide what to get for example nodes. For example:
# https://aksnodepoo-aksnodepooldemo--0b84cf-xzev55zg.hcp.westus2.azmk8s.io/api/v1/pods

# Create a token for the default service account in the default namespace
TOKEN=$(kubectl create token default) 

# Make the call using curl
curl -k -H "Authorization: Bearer $TOKEN" https://aksnodepoo-aksnodepooldemo--0b84cf-xzev55zg.hcp.westus2.azmk8s.io/api/v1/pods

# This should fail with
# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "pods is forbidden: User \"system:serviceaccount:default:default\" cannot list resource \"pods\" in API group \"\" at the cluster scope",
#   "reason": "Forbidden",
#   "details": {
#     "kind": "pods"
#   },
#   "code": 403
# }

# because the service account does not have permissions to call the API. 
# Therefore you need to create a role binding to assign the cluster-admin role to the default service account in the default namespace
kubectl create clusterrolebinding default-sa-admin --clusterrole=cluster-admin --serviceaccount=default:default

# Make the call again it should succeed this time
curl -k -H "Authorization: Bearer $TOKEN" https://aksnodepoo-aksnodepooldemo--0b84cf-xzev55zg.hcp.westus2.azmk8s.io/api/v1/pods

# STEP 5: Clean up the resources
# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait