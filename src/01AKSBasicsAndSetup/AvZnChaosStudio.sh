# STEP 1: Environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_B4pls_v2"

# Step 1: Register the Chaos Studio Resource Provider
az provider register --namespace Microsoft.Chaos --wait
az provider show --namespace Microsoft.Chaos --query "registrationState" -o tsv

# Step 2: Enable Chaos Studio on Your AKS Cluster
# Set variables
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)


# Get the AKS cluster resource ID
export AKS_RESOURCE_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query id -o tsv)

# Enable Chaos Target on AKS (service-direct target)
az rest --method put \
  --uri "https://management.azure.com${AKS_RESOURCE_ID}/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh?api-version=2024-01-01" \
  --body '{"properties":{}}'

# Step 3: Enable Chaos Mesh Capability
# Enable the Pod Chaos capability
az rest --method put \
  --uri "https://management.azure.com${AKS_RESOURCE_ID}/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh/capabilities/PodChaos-2.1?api-version=2024-01-01" \
  --body '{"properties":{}}'

# Enable the Network Chaos capability (optional)
az rest --method put \
  --uri "https://management.azure.com${AKS_RESOURCE_ID}/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh/capabilities/NetworkChaos-2.1?api-version=2024-01-01" \
  --body '{"properties":{}}'

# Step 4: Install Chaos Mesh on AKS
# STEP 4A: Install Helm

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Add Chaos Mesh Helm repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Create namespace
kubectl create namespace chaos-testing

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace chaos-testing --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock --version 2.6.3

# Verify installation
kubectl get pods -n chaos-testing

# Step 5: Create the Chaos Experiment JSON File: Create a file named zone-failure-experiment.json

# Step 6: Create the Chaos Experiment
# Replace <SUBSCRIPTION_ID> in the JSON file first
# sed -i "s/<SUBSCRIPTION_ID>/$SUBSCRIPTION_ID/g" zone-failure-experiment.json
# Do it manually !!!


# Create the experiment
az rest --method put --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/aks-zone-failure-test?api-version=2024-01-01" --body @src/01AKSBasicsAndSetup/AvZnZoneFailureExperiment.json 

# Step 7: Grant Permissions to the Experiment
# Get the experiment's managed identity principal ID
export EXPERIMENT_PRINCIPAL_ID=$(az rest --method get \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/aks-zone-failure-test?api-version=2024-01-01" \
  --query "identity.principalId" -o tsv)

# Assign Azure Kubernetes Service Cluster Admin Role
az role assignment create \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --assignee-object-id $EXPERIMENT_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope $AKS_RESOURCE_ID

# Step 8: Run the Experiment
# Start the experiment
az rest --method post \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/aks-zone-failure-test/start?api-version=2024-01-01"

# Step 9: Monitor the Experiment
# Check experiment status
az rest --method get \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/aks-zone-failure-test/executions?api-version=2024-01-01" \
  --query "value[0].{Status:properties.status, StartTime:properties.startedAt}" -o table

# Watch pods during the experiment
kubectl get pods -o wide -w

# Check which zone pods are running in
kubectl get pods -o custom-columns='NAME:metadata.name,NODE:spec.nodeName,STATUS:status.phase'

What to Observe
During the experiment:

Pods in Zone 2 will fail - Watch them transition to Error or Terminating
Kubernetes will reschedule - New pods should start on nodes in Zones 1 and 3
Your topology spread - Should redistribute pods across remaining zones

# Check pod distribution by zone
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}' | while read pod node; do
  zone=$(kubectl get node $node -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
  echo "$pod -> $node -> $zone"
done


# NAME                                READY   STATUS             RESTARTS      AGE    IP             NODE                                 NOMINATED NODE   READINESS GATES
# mypod-deployment-594b8bdb8c-7xwlm   1/1     Running            0             122m   10.244.8.102   aks-mynodepool-12265658-vmss000005   <none>           <none> 
# mypod-deployment-594b8bdb8c-95h46   1/1     Running            0             122m   10.244.5.208   aks-mynodepool-12265658-vmss000000   <none>           <none> 
# mypod-deployment-594b8bdb8c-b9wkb   1/1     Running            0             122m   10.244.8.163   aks-mynodepool-12265658-vmss000005   <none>           <none> 
# mypod-deployment-594b8bdb8c-fns2d   1/1     Running            0             122m   10.244.4.83    aks-mynodepool-12265658-vmss000002   <none>           <none>
# mypod-deployment-594b8bdb8c-fsljb   0/1     CrashLoopBackOff   5 (32s ago)   122m   10.244.7.130   aks-mynodepool-12265658-vmss000001   <none>           <none> 
# mypod-deployment-594b8bdb8c-gx6x6   0/1     CrashLoopBackOff   5 (24s ago)   122m   10.244.6.183   aks-mynodepool-12265658-vmss000004   <none>           <none> 
# mypod-deployment-594b8bdb8c-jqk9j   1/1     Running            0             122m   10.244.3.239   aks-mynodepool-12265658-vmss000003   <none>           <none> 
# mypod-deployment-594b8bdb8c-knrxx   1/1     Running            0             122m   10.244.5.167   aks-mynodepool-12265658-vmss000000   <none>           <none> 
# mypod-deployment-594b8bdb8c-qznj4   1/1     Running            0             122m   10.244.3.105   aks-mynodepool-12265658-vmss000003   <none>           <none> 
# mypod-deployment-594b8bdb8c-rxpdg   0/1     CrashLoopBackOff   5 (23s ago)   122m   10.244.7.55    aks-mynodepool-12265658-vmss000001   <none>           <none> 
# mypod-deployment-594b8bdb8c-t7tz8   0/1     CrashLoopBackOff   5 (39s ago)   122m   10.244.6.241   aks-mynodepool-12265658-vmss000004   <none>           <none> 
# mypod-deployment-594b8bdb8c-zwn9f   1/1     Running            0             122m   10.244.8.166   aks-mynodepool-12265658-vmss000005   <none>           <none>


kubectl cordon node1 node2
kubectl delete pod podA podB ...


# STEP 10: 
# Delete the experiment

az rest --method delete \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/aks-zone-failure-test?api-version=2024-01-01"

# Uninstall Chaos Mesh (optional)
helm uninstall chaos-mesh -n chaos-testing
kubectl delete namespace chaos-testing