
################################################################################################################################
# NOTE:  A similar LAB exists at https://azure-samples.github.io/aks-labs/docs/security/workload-identity-lab/
# The following steps are from https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster?tabs=new-cluster
################################################################################################################################


# STEP 1: Create Resource Group
export RANDOM_ID="$(openssl rand -hex 3)"
export RESOURCE_GROUP="workload-rg$RANDOM_ID"
export LOCATION="westus2"
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"

# STEP 2: Create AKS Cluster with Workload Identity and OIDC enabled
export CLUSTER_NAME="myAKSCluster$RANDOM_ID"
az aks create --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys

# STEP 3: Retrieve the OIDC issuer URL
export AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"
echo "AKS OIDC Issuer URL: ${AKS_OIDC_ISSUER}"

# STEP 4: Create a managed identity
export SUBSCRIPTION="$(az account show --query id --output tsv)"

# Create a user-assigned managed identity using the az identity create command.
export USER_ASSIGNED_IDENTITY_NAME="myIdentity$RANDOM_ID"
echo "Creating user-assigned managed identity: ${USER_ASSIGNED_IDENTITY_NAME}"
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"

# Get the client ID of the managed identity and save it to an environment variable using the [az identity show][az-identity-show] command
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"
echo "User-assigned managed identity client ID: ${USER_ASSIGNED_CLIENT_ID}"

# STEP 5: Create a Kubernetes service account

az aks get-credentials --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}"

# Create a Kubernetes service account and annotate it with the client ID of the managed identity by applying the following manifest using the kubectl apply command
export SERVICE_ACCOUNT_NAME="workload-identity-sa$RANDOM_ID"
export SERVICE_ACCOUNT_NAMESPACE="default"

echo "Creating Kubernetes service account: ${SERVICE_ACCOUNT_NAME} in namespace: ${SERVICE_ACCOUNT_NAMESPACE}"


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
EOF

# STEP 6: Create the federated identity credential
export FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity$RANDOM_ID"
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange

echo "Created federated identity credential: ${FEDERATED_IDENTITY_CREDENTIAL_NAME}"

# STEP 7: Create a key vault with Azure RBAC authorization
# Create a key vault with purge protection and Azure RBAC authorization enabled
# Ensure the key vault name is between 3-24 characters

export KEYVAULT_NAME="kv-workload-id$RANDOM_ID" 

az keyvault create --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --enable-purge-protection --enable-rbac-authorization

# Get the key vault resource ID and save it to an environment variable
export KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "${RESOURCE_GROUP}" --name "${KEYVAULT_NAME}" --query id --output tsv)
echo "Key Vault Resource ID: ${KEYVAULT_RESOURCE_ID}"

# STEP 8: Assign RBAC permissions for key vault management

export CALLER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign yourself the Azure RBAC Key Vault Secrets Officer role so that you can create a secret in the new key vault
az role assignment create --assignee "${CALLER_OBJECT_ID}" --role "Key Vault Secrets Officer" --scope "${KEYVAULT_RESOURCE_ID}"

# STEP 9: Create and configure secret access
# Create a secret in the key vault
export KEYVAULT_SECRET_NAME="my-secret$RANDOM_ID"
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name "${KEYVAULT_SECRET_NAME}" --value "Hello\!"

# Get the principal ID of the user-assigned managed identity and save it to an environment variable
export IDENTITY_PRINCIPAL_ID=$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)
echo $"User-assigned managed identity principal ID: ${IDENTITY_PRINCIPAL_ID}"

# Assign the Key Vault Secrets User role to the user-assigned managed identity 
# This step gives the managed identity permission to read secrets from the key vault.

az role assignment create --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" --role "Key Vault Secrets User" --scope "${KEYVAULT_RESOURCE_ID}" --assignee-principal-type ServicePrincipal

# Create an environment variable for the key vault URL
export KEYVAULT_URL="$(az keyvault show --resource-group "${RESOURCE_GROUP}" --name ${KEYVAULT_NAME} --query properties.vaultUri --output tsv)"
echo "Key Vault URL: ${KEYVAULT_URL}"

# STEP 10: Deploy a verification pod and test access
# Deploy a pod to verify that the workload identity can access the secret in the key vault. The following example uses the ghcr.io/azure/azure-workload-identity/msal-go image,
# which contains a sample application that retrieves a secret from Azure Key Vault using Microsoft Entra Workload ID

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
    name: sample-workload-identity-key-vault
    namespace: ${SERVICE_ACCOUNT_NAMESPACE}
    labels:
        azure.workload.identity/use: "true"
spec:
    serviceAccountName: ${SERVICE_ACCOUNT_NAME}
    containers:
      - image: ghcr.io/azure/azure-workload-identity/msal-go
        name: oidc
        env:
          - name: KEYVAULT_URL
            value: ${KEYVAULT_URL}
          - name: SECRET_NAME
            value: ${KEYVAULT_SECRET_NAME}
    nodeSelector:
        kubernetes.io/os: linux
EOF

# Wait for the pod to be in the Ready state using the kubectl wait command.
kubectl wait --namespace ${SERVICE_ACCOUNT_NAMESPACE} --for=condition=Ready pod/sample-workload-identity-key-vault --timeout=120s

# Check that the SECRET_NAME environment variable is set in the pod using the kubectl describe command.
kubectl describe pod sample-workload-identity-key-vault | grep "SECRET_NAME:"

# Verify that pods can get a token and access the resource using the kubectl logs command.
kubectl logs sample-workload-identity-key-vault

# If successful, the output should be similar to the following example:
# I0114 10:35:09.795900       1 main.go:63] "successfully got secret" secret="Hello\\!"

# STEP 11: Clean-up

# Delete resource group
echo "Deleting resource group"
az group delete --name $RESOURCE_GROUP --yes --no-wait