# The original content is here: https://learn.microsoft.com/en-us/azure/aks/keda-workload-identity

# STEP 1: Environment variables
export CLUSTER_NAME="aksnodepooldemo"
export RESOURCE_GROUP="aksnodepooldemo-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_D4ds_v5"
export SB_NAME="akskedademosb"
export SB_HOSTNAME="${SB_NAME}.servicebus.windows.net"
export SB_QUEUE_NAME="akskedademosb-queue"
export MI_NAME="akskedademosb-mi"
export FED_WORKLOAD="akskedademosb-federated-workload"
export FED_KEDA="akskedademosb-federated-keda"

# STEP 2: Create the AKS cluster and the user node pool 
# Create a resource group
# Create a cluster with a single Ubuntu node pool
echo "Creating the resource group"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Create a cluster with a single Ubuntu node pool and Windows support"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-keda --enable-workload-identity --enable-oidc-issuer  --os-sku Ubuntu --location $LOCATION  --generate-ssh-keys

#Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 2 --mode User

# Check that KEDA is installed
echo "Checking KEDA installation"
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "workloadAutoScalerProfile.keda.enabled"

# Get AKS cluster credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Verify KEDA is running on your cluster
kubectl get pods -n kube-system

# output similar to:
keda-admission-webhooks-**********-2n9zl           1/1     Running   0            3d18h
keda-admission-webhooks-**********-69dkg           1/1     Running   0            3d18h
keda-operator-*********-4hb5n                      1/1     Running   0            3d18h
keda-operator-*********-pckpx                      1/1     Running   0            3d18h
keda-operator-metrics-apiserver-**********-gqg4s   1/1     Running   0            3d18h
keda-operator-metrics-apiserver-**********-trfcb   1/1     Running   0            3d18h

# Checking the KEDA version
kubectl get crd/scaledobjects.keda.sh -o yaml

# STEP 3: Create an Azure Service Bus

az servicebus namespace create --name $SB_NAME --resource-group $RESOURCE_GROUP --disable-local-auth

az servicebus queue create --name $SB_QUEUE_NAME --namespace $SB_NAME --resource-group $RESOURCE_GROUP


# STEP 4: Create a managed identity

# Create a managed identity
export MI_CLIENT_ID=$(az identity create --name $MI_NAME --resource-group $RESOURCE_GROUP --query "clientId" --output tsv)

# Get the OIDC issuer URL
export OIDC_ISSUER_URL=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" --output tsv)

# Create a federated credential between the managed identity and the namespace and service account used by the workload 
az identity federated-credential create --name $FED_WORKLOAD --identity-name $MI_NAME --resource-group $RESOURCE_GROUP --issuer $OIDC_ISSUER_URL --subject system:serviceaccount:default:$MI_NAME --audience api://AzureADTokenExchange

# Create a second federated credential between the managed identity and the namespace and service account used by KEDA
az identity federated-credential create --name $FED_KEDA --identity-name $MI_NAME --resource-group $RESOURCE_GROUP --issuer $OIDC_ISSUER_URL --subject system:serviceaccount:kube-system:keda-operator --audience api://AzureADTokenExchange

# STEP 5: Create role assignments
# Get the object ID for the managed identity
export MI_OBJECT_ID=$(az identity show --name $MI_NAME --resource-group $RESOURCE_GROUP --query "principalId" --output tsv)

# Get the Service Bus namespace resource ID 
export SB_ID=$(az servicebus namespace show --name $SB_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)

# Assign the Azure Service Bus Data Owner role to the managed identity
az role assignment create --role "Azure Service Bus Data Owner" --assignee-object-id $MI_OBJECT_ID --assignee-principal-type ServicePrincipal --scope $SB_ID

# STEP 6: Enable Workload Identity on KEDA operator
# After creating the federated credential for the keda-operator ServiceAccount, 
# you will need to manually restart the keda-operator pods to ensure Workload Identity environment variables are injected into the pod
kubectl rollout restart deploy keda-operator -n kube-system

# Confirm the keda-operator pods restart
kubectl get pod -n kube-system -lapp=keda-operator -w

# Confirm the Workload Identity environment variables have been injected.
export KEDA_POD_ID=$(kubectl get po -n kube-system -l app.kubernetes.io/name=keda-operator -ojsonpath='{.items[0].metadata.name}')

kubectl describe po $KEDA_POD_ID -n kube-system

# Deploy a KEDA TriggerAuthentication resource that includes the User-Assigned Managed Identity's Client ID
kubectl apply -f - <<EOF
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-servicebus-auth
  namespace: default  # this must be same namespace as the ScaledObject/ScaledJob that will use it
spec:
  podIdentity:
    provider:  azure-workload
    identityId: $MI_CLIENT_ID
EOF

# STEP 7: Publish messages to Azure Service Bus
# Create a new ServiceAccount for the workloads

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $MI_CLIENT_ID
  name: $MI_NAME
EOF

# Deploy a Job to publish 100 messages
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: myproducer
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: $MI_NAME
      containers:
      - image: ghcr.io/azure-samples/aks-app-samples/servicebusdemo:latest
        name: myproducer
        resources: {}
        env:
        - name: OPERATION_MODE
          value: "producer"
        - name: MESSAGE_COUNT
          value: "100"
        - name: AZURE_SERVICEBUS_QUEUE_NAME
          value: $SB_QUEUE_NAME
        - name: AZURE_SERVICEBUS_HOSTNAME
          value: $SB_HOSTNAME
      restartPolicy: Never
EOF

# STEP 8: Consume messages from Azure Service Bus
# Deploy a ScaledJob resource to consume the messages. The scale trigger will be configured to scale out every 10 messages. 
# The KEDA scaler will create 10 jobs to consume the 100 messages.

kubectl apply -f - <<EOF
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: myconsumer-scaledjob
spec:
  jobTargetRef:
    template:
      metadata:
        labels:
          azure.workload.identity/use: "true"
      spec:
        serviceAccountName: $MI_NAME
        containers:
        - image: ghcr.io/azure-samples/aks-app-samples/servicebusdemo:latest
          name: myconsumer
          env:
          - name: OPERATION_MODE
            value: "consumer"
          - name: MESSAGE_COUNT
            value: "10"
          - name: AZURE_SERVICEBUS_QUEUE_NAME
            value: $SB_QUEUE_NAME
          - name: AZURE_SERVICEBUS_HOSTNAME
            value: $SB_HOSTNAME
        restartPolicy: Never
  triggers:
  - type: azure-servicebus
    metadata:
      queueName: $SB_QUEUE_NAME
      namespace: $SB_NAME
      messageCount: "10"
    authenticationRef:
      name: azure-servicebus-auth
EOF

# Verify the KEDA scaler worked as intended.
kubectl describe scaledjob myconsumer-scaledjob

# You should see events similar to the following
# Events:
# Type     Reason              Age   From           Message
# ----     ------              ----  ----           -------
# Normal   KEDAScalersStarted  10m   scale-handler  Started scalers watch
# Normal   ScaledJobReady      10m   keda-operator  ScaledJob is ready for scaling
# Warning  KEDAScalerFailed    10m   scale-handler  context canceled
# Normal   KEDAJobsCreated     10m   scale-handler  Created 10 jobs


# STEP 9: Clean up resources
# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait