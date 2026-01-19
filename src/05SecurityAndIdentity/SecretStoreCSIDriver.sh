# STEP 1: Create a resource group and an AKS cluster with the Secret Store CSI driver enabled

az group create --name myaks-rg --location westus2

az aks create --name myAKSCluster --resource-group myaks-rg --enable-addons azure-keyvault-secrets-provider --enable-managed-identity --generate-ssh-keys

# The previous command creates a user-assigned managed identity, azureKeyvaultSecretsProvider, to access Azure resources. 
#  "addonProfiles": {
#     "azureKeyvaultSecretsProvider": {
#       "config": {
#         "enableSecretRotation": "false",
#         "rotationPollInterval": "2m"
#       },
#       "enabled": true,
#       "identity": {
#         "clientId": "1ad99278-8b56-45fe-9074-82640c5d56f1",
#         "objectId": "39da4c5c-b66d-4cc4-b052-863bcbde8606",
#         "resourceId": "/subscriptions/0b84cfe4-f9d9-4e33-84f5-5feec95b370e/resourcegroups/MC_myaks-rg_myAKSCluster_westus2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azurekeyvaultsecretsprovider-myakscluster"
#       }

# STEP 2: Verify the Azure Key Vault provider for Secrets Store CSI Driver installation
az aks get-credentials --name myAKSCluster --resource-group myaks-rg 

# Verify that each node in your cluster's node pool has a Secrets Store CSI Driver pod and a Secrets Store Provider Azure pod running.
kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)'

# STEP 3: Create a Key Vault and a secret
# Create a new Azure key vault
az keyvault create --name mykv2026 --resource-group myaks-rg --location westus2 --enable-rbac-authorization

# Update an existing Azure key vault
# az keyvault update --name mykv --resource-group myaks-rg --location westus2 --enable-rbac-authorization

# Assign the necessary role to the user on the KV

export KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "myaks-rg" --name "mykv2026" --query id --output tsv)
export CALLER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign yourself the Azure RBAC Key Vault Secrets Officer role so that you can create a secret in the new key vault
az role assignment create --assignee "${CALLER_OBJECT_ID}" --role "Key Vault Secrets Officer" --scope "${KEYVAULT_RESOURCE_ID}"

# set a plain-text secret called ExampleSecret.
az keyvault secret set --vault-name mykv2026 --name ExampleSecret --value MyAKSExampleSecret

# STEP 4: Create a service connection in AKS with Service Connector
az aks connection create keyvault --connection aks2kv --resource-group myaks-rg --name myAKSCluster --target-resource-group myaks-rg --vault mykv2026 --enable-csi --client-type none

# STEP 5: Test the connection
git clone https://github.com/Azure-Samples/serviceconnector-aks-samples.git
cd serviceconnector-aks-samples/azure-keyvault-csi-provider

# In the secret_provider_class.yaml file, replace the following placeholders with your Azure Key Vault information:
# Replace <AZURE_KEYVAULT_NAME> with the name of the key vault you created and connected.
# Replace <AZURE_KEYVAULT_TENANTID> with the tenant ID of the key vault.
# Replace <AZURE_KEYVAULT_CLIENTID> with identity client ID of the azureKeyvaultSecretsProvider addon.
# Replace <KEYVAULT_SECRET_NAME> with the key vault secret you created. For example, ExampleSecret.

# Deploy the SecretProviderClass CRD using the kubectl apply command.
kubectl apply -f secret_provider_class.yaml

# Deploy the Pod manifest file using the kubectl apply command.
kubectl apply -f pod.yaml

# STEP 6: Verify the connection

# Verify the pod was created successfully using the kubectl get command
kubectl get pod/sc-demo-keyvault-csi

# Show the secrets held in the secrets store using the kubectl exec command
kubectl exec sc-demo-keyvault-csi -- ls /mnt/secrets-store/
kubectl exec sc-demo-keyvault-csi -- cat /mnt/secrets-store/ExampleSecret