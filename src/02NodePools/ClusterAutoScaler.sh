# STEP 1: Set the environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export NODEPOOL_NAME_2="nodepool2"
export NODEPOOL_NAME_WINDOWS="winpol"
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

# INFORMATION
# Enable the cluster autoscaler on an existing cluster
# az aks update --resource-group myResourceGroup --name myAKSCluster --enable-cluster-autoscaler --min-count 1 --max-count 3

# Disable the cluster autoscaler on a cluster
# az aks update --resource-group myResourceGroup --name myAKSCluster --disable-cluster-autoscaler

# STEP 3: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 1 --mode User

# STEP 4: Add a third node pool
echo "Adding a third node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_2 --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 1 --mode User

# STEP 5: Check the node pool's autoscale settings

# Query a specific node pool's autoscale setting:
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --query "enableAutoScaling"

# Get full autoscale details (min/max count included):
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --query "{enableAutoScaling: enableAutoScaling, minCount: minCount, maxCount: maxCount}"

# List all node pools with their autoscale settings:
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --query "[].{name: name, enableAutoScaling: enableAutoScaling, minCount: minCount, maxCount: maxCount}" -o table

# Name        EnableAutoScaling    MinCount    MaxCount
# ----------  -------------------  ----------  ----------
# nodepool1   True                 1           3
# mynodepool  False
# nodepool2   False

# STEP 6: Deploy the pods and check their distribution.

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl apply -f ./src/03VersionsAndUpgrades/Simple_Deployment.yaml

kubectl get pods -o wide

# STEP 7: At this point the pods should be distributed among the two user node pools each having one node.
# Let's increase the size of the deployment to trigger the cluster autoscaler.

# Let's check the node pod capacity
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --query "maxPods"
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME_2 --query "maxPods"

# Let's scale to 300 pods and check the pods
kubectl scale deployment pod-upgrade --replicas=300
kubectl get pods -o wide

# If all pods are running then double the replica count
kubectl scale deployment pod-upgrade --replicas=600
kubectl get pods -o wide

# There should be pods with the "pending" status until new nodes are created by the cluster autoscaler
# Copy one of such pod's name and check the events with 
kubectl describe pod <POD_NAME>

# The output should be similar to:
#   Type     Reason             Age   From                Message
#   ----     ------             ----  ----                -------
#   Warning  FailedScheduling   2m7s  default-scheduler   0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Too many pods. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
#   Normal   NotTriggerScaleUp  2m5s  cluster-autoscaler  pod didn't trigger scale-up: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}

# STEP 8: Let's set the autoscale feature on the second user node pool
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --enable-cluster-autoscaler --min-count 1 --max-count 3

# Let's check the nodes. The node count should not increase immediately
kubectl get node

# Wait for a few minutes and check the nodes again. New nodes should be created in the user node pool
kubectl get node
# Check the pods again
kubectl get pods -o wide
# The pending pods should be running now. 
# Check the pod description again to confirm that the cluster autoscaler has created new nodes
kubectl describe pod <POD_NAME>

# Type     Reason             Age                    From                Message
#   ----     ------             ----                   ----                -------
#   Warning  FailedScheduling   5m50s (x2 over 10m)    default-scheduler   0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Too many pods. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
#   Normal   NotTriggerScaleUp  5m34s (x32 over 10m)   cluster-autoscaler  pod didn't trigger scale-up: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}
#   Normal   TriggeredScaleUp   3m3s                   cluster-autoscaler  pod triggered scale-up: [{aks-mynodepool-15339926-vmss 1->2 (max: 3)}]
#   Warning  FailedScheduling   2m23s (x2 over 2m25s)  default-scheduler   0/4 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 node(s) had untolerated taint {node.cloudprovider.kubernetes.io/uninitialized: true}, 2 Too many pods. preemption: 0/4 nodes are available: 2 No preemption victims found for incoming pod, 2 Preemption is not helpful for scheduling.
#   Warning  FailedScheduling   2m13s (x2 over 2m16s)  default-scheduler   0/4 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 node(s) had untolerated taint {node.kubernetes.io/not-ready: }, 2 Too many pods. preemption: 0/4 nodes are available: 2 No preemption victims found for incoming pod, 2 Preemption is not helpful for scheduling.
#   Normal   Scheduled          2m12s                  default-scheduler   Successfully assigned default/pod-upgrade-5cd9bdbd67-4kq6x to aks-mynodepool-15339926-vmss000001    
#   Warning  Failed             2m4s                   kubelet             Error: ErrImagePull
#   Warning  Failed             2m4s                   kubelet             Failed to pull image "nginx:latest": pull QPS exceeded
#   Normal   BackOff            2m3s                   kubelet             Back-off pulling image "nginx:latest"
#   Warning  Failed             2m3s                   kubelet             Error: ImagePullBackOff
#   Normal   Pulling            109s (x2 over 2m4s)    kubelet             Pulling image "nginx:latest"
#   Normal   Pulled             108s                   kubelet             Successfully pulled image "nginx:latest" in 558ms (558ms including waiting). Image size: 62870438 bytes.
#   Normal   Created            108s                   kubelet             Created container: nginx
#   Normal   Started            108s                   kubelet             Started container nginx

# Checking the node pools' settings for autoscale
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --query "[].{name: name, enableAutoScaling: enableAutoScaling, minCount: minCount, maxCount: maxCount}" -o table

# Name        EnableAutoScaling    MinCount    MaxCount
# ----------  -------------------  ----------  ----------
# nodepool1   True                 1           3
# mynodepool  True                 1           3
# nodepool2   False

# STEP 8: Observe the scale operation
kubectl get events --field-selector source=cluster-autoscaler,reason=NotTriggerScaleUp
kubectl get events --field-selector source=cluster-autoscaler
kubectl get configmap -n kube-system cluster-autoscaler-status -o yaml

# STEP 9: Trigger a scale down with setting the replica count to 6 again
kubectl scale deployment pod-upgrade --replicas=6
kubectl get pods -o wide
kubectl get nodes -o wide

# After almost 10 minutes the number of nodes should decrease back to the original count.
# scale-down-unneeded-time

# STEP 10: Configure cluster autoscaler profile for aggressive scale down
# The replica count will be set to 600 again to trigger scale up
# Then the replica count will be set back to 6 to observe faster scale down

# https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler?tabs=azure-cli#configure-cluster-autoscaler-profile-for-aggressive-scale-down
az aks update --resource-group $RESOURCE_GROUP  --name $CLUSTER_NAME --cluster-autoscaler-profile scan-interval=30s,scale-down-delay-after-add=0m,scale-down-delay-after-failure=1m,scale-down-unneeded-time=3m,scale-down-unready-time=3m,max-graceful-termination-sec=30,skip-nodes-with-local-storage=false,max-empty-bulk-delete=1000,max-total-unready-percentage=100,ok-total-unready-count=1000,max-node-provision-time=15m 

kubectl scale deployment pod-upgrade --replicas=600

kubectl get pods -o wide
kubectl describe pod <POD_NAME>

#   Type     Reason            Age   From                Message
#   ----     ------            ----  ----                -------
#   Warning  FailedScheduling  44s   default-scheduler   0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Too many pods. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
#   Normal   TriggeredScaleUp  22s   cluster-autoscaler  pod triggered scale-up: [{aks-mynodepool-15339926-vmss 1->2 (max: 3)}]

# Trigger a scale down with setting the replica count to 6 again
kubectl scale deployment pod-upgrade --replicas=6
kubectl get pods -o wide

date
kubectl get nodes -o wide

# wait for 3-4 minutes and check the nodes again
date
kubectl get nodes -o wide

# NAME                                 STATUS     ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# aks-mynodepool-15339926-vmss000000   NotReady   <none>   112m    v1.33.5   10.224.0.5    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1
# aks-mynodepool-15339926-vmss000002   Ready      <none>   9m54s   v1.33.5   10.224.0.7    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1
# aks-nodepool1-19782146-vmss000000    Ready      <none>   118m    v1.33.5   10.224.0.4    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1
# aks-nodepool2-29933112-vmss000000    Ready      <none>   109m    v1.33.5   10.224.0.6    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1

# And, then
# NAME                                 STATUS   ROLES    AGE    VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# aks-mynodepool-15339926-vmss000002   Ready    <none>   11m    v1.33.5   10.224.0.7    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1
# aks-nodepool1-19782146-vmss000000    Ready    <none>   120m   v1.33.5   10.224.0.4    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1
# aks-nodepool2-29933112-vmss000000    Ready    <none>   111m   v1.33.5   10.224.0.6    <none>        Ubuntu 22.04.5 LTS   5.15.0-1102-azure   containerd://1.7.29-1

# STEP 11: Cleanup the cluster
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait