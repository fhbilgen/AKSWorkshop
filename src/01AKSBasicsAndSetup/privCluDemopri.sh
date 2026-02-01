# STEP 1: Set the environment variables and create an AKS cluster
export CLUSTER_NAME="aksprivclu"
export RESOURCE_GROUP="aksprivclu-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"

# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a PRIVATE cluster with a single Ubuntu node pool"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 1 --os-sku Ubuntu --location $LOCATION --load-balancer-sku standard --enable-private-cluster --generate-ssh-keys

# STEP: 3
###########################################################
###   Deploy the pods and check their distribution      ###
###   They should be running only on the user node pool ###
###########################################################

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# STEP 4: Get the API Server access information
export CONTROL_PLAN_IP=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query fqdn --output tsv)

ping $CONTROL_PLAN_IP

# ping should fail because the cluster is private
# ^C
# --- aksprivclu-aksprivclu-rg-0b84cf-06gfz93m.hcp.westus2.azmk8s.io ping statistics ---
# 137 packets transmitted, 0 received, 100% packet loss, time 141860ms

kubectl cluster-info

# kubectl also fails
# To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
# Unable to connect to the server: dial tcp: lookup aksprivclu-aksprivclu-rg-0b84cf-5zxu9bfa.328816d6-1bd5-4907-89cb-c5c193a19e3f.privatelink.westus2.azmk8s.io on 172.22.48.1:53: read udp 172.22.53.134:51425->172.22.48.1:53: i/o timeout

# Hence it is not possible to make a call to the API endpoint 

# STEP 4: Communicate with command invoke

az aks command invoke --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --command "kubectl get pods -n kube-system"

# STEP 5: Using Cloud Shell
# First configure vnet
# Then launch cloud shell

# In this option you can access the API server

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


# STEP 6: Using Run-Command in the Portal
# Kubernetes -> Kubernetes Resources -> Run command

# STEP 7: Connect via Bastion
# To deploy Bastion with default settings:

# Go to your virtual network (or VM). In the left pane, select Connect > Bastion.
# In the Bastion pane, select Deploy Bastion.
# Bastion deploys automatically with default settings. The deployment process takes about 10 minutes to complete.

az aks bastion --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --admin --bastion /subscriptions/0b84cfe4-f9d9-4e33-84f5-5feec95b370e/resourceGroups/MC_aksprivclu-rg_aksprivclu_westus2/providers/Microsoft.Network/bastionHosts/aks-vnet-32668130-bastion

# STEP 8: Clean up the resources
# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait