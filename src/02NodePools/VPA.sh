# STEP 1: Set the environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export NODEPOOL_NAME_WINDOWS="winpol"
export VM_SIZE="Standard_D4ds_v5"


# STEP 2: Create a resource group & Create a cluster with a single Ubuntu node pool
echo "Creating resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and VPA enabled"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 1  --enable-vpa --generate-ssh-keys

# Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# STEP 3: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 1 --mode User

# STEP 4: Start testing VPA 
# we create a deployment with two pods, each running a single container that requests 100 millicore and tries to utilize slightly above 500 millicores. We also create a VPA config pointing at the deployment. 
# The VPA observes the behavior of the pods, and after about five minutes, updates the pods to request 500 millicores.

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# deploy the hamster application
kubectl apply -f src/02NodePools/hamster.yaml

# view the running pods
kubectl get pods -l app=hamster

# kubectl describe pod hamster-<example-pod>
kubectl describe pod hamster-<example-pod>

# Output should be similar to below:
# hamster:
#     Container ID:  containerd://
#     Image:         k8s.gcr.io/ubuntu-slim:0.1
#     Image ID:      sha256:
#     Port:          <none>
#     Host Port:     <none>
#     Command:
#       /bin/sh
#     Args:
#       -c
#       while true; do timeout 0.5s yes >/dev/null; sleep 0.5s; done
#     State:          Running
#       Started:      Wed, 28 Sep 2022 15:06:14 -0400
#     Ready:          True
#     Restart Count:  0
#     Requests:
#       cpu:        100m        <=======
#       memory:     50Mi        <=======
#     Environment:  <none>

# Monitor the pods
kubectl get --watch pods -l app=hamster

# When the new hamster pod starts, you can view the updated CPU and Memory reservations
kubectl describe pod hamster-<example-pod>

# The output should be similar to below:
# State:          Running
#   Started:      Wed, 28 Sep 2022 15:09:51 -0400
# Ready:          True
# Restart Count:  0
# Requests:
#   cpu:        587m
#   memory:     262144k
# Environment:  <none>

# View updated recommendations from VPA using the kubectl describe command to describe the hamster-vpa resource information.
kubectl describe vpa/hamster-vpa

# Spec:
#   Resource Policy:
#     Container Policies:
#       Container Name:  *
#       Controlled Resources:
#         cpu
#         memory
#       Max Allowed:
#         Cpu:     1
#         Memory:  500Mi
#       Min Allowed:
#         Cpu:     100m
#         Memory:  50Mi
#   Target Ref:
#     API Version:  apps/v1
#     Kind:         Deployment
#     Name:         hamster
#   Update Policy:
#     Update Mode:  Auto    <======= UPDATE MODE !!!
# Status:
#   Conditions:
#     Last Transition Time:  2026-01-22T15:10:50Z
#     Status:                True
#     Type:                  RecommendationProvided <=====
#   Recommendation:
#     Container Recommendations:
#       Container Name:  hamster        <======
#       Lower Bound:
#         Cpu:     489m
#         Memory:  50Mi
#       Target:
#         Cpu:     587m
#         Memory:  50Mi
#       Uncapped Target:
#         Cpu:     587m
#         Memory:  11500k
#       Upper Bound:
#         Cpu:     1
#         Memory:  500Mi

# The VerticalPodAutoscaler object automatically sets resource requests on pods with an updateMode of Auto. 
# You can set a different value depending on your requirements and testing. 

# Create the pod using the kubectl create command.
kubectl create -f src/02NodePools/azure-autodeploy.yaml 

kubectl get pod

kubectl create -f src/02NodePools/azure-vpa-auto.yaml 

kubectl get pods

kubectl get pod <pod-name> --output yaml

kubectl get vpa vpa-auto --output yaml

# Follow from https://learn.microsoft.com/en-us/azure/aks/use-vertical-pod-autoscaler#set-vertical-pod-autoscaler-requests

# Create the pod using the kubectl create command.
kubectl apply -f extra-recommender.yaml

