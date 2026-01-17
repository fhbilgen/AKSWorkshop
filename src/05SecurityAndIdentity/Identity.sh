# STEP1: Setup Resource Group
RAND=$RANDOM
export RAND
echo "Random resource identifier will be: ${RAND}"

export LOCATION=westus2
export RG_NAME=myresourcegroup$RAND
export AKS_NAME=myakscluster$RAND
export AKV_NAME="mykeyvault$RAND"

az group create --name ${RG_NAME} --location ${LOCATION}

echo $RG_NAME $AKS_NAME $LOCATION 

# STEP 2: Create AKS cluster with Managed Identity and Workload Identity enabled
az aks create --resource-group $RG_NAME --name $AKS_NAME --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium --network-policy cilium --enable-managed-identity --enable-workload-identity --enable-oidc-issuer --generate-ssh-keys

az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME

# STEP 3: Setup Azure Key Vault

export AKV_ID=$(az keyvault create --resource-group $RG_NAME --name $AKV_NAME --enable-rbac-authorization --query id --output tsv)
echo $AKV_ID

# STEP 4: Enable Workload Identity and OpenID Connect (OIDC) on an AKS cluster

# Check if workload identity is enabled in AKS
az aks show --resource-group $RG_NAME --name $AKS_NAME --query "securityProfile.workloadIdentity.enabled" --output tsv

# Check if OIDC Issuer is enabled in the AKS cluster
az aks show --resource-group $RG_NAME --name $AKS_NAME --query "oidcIssuerProfile.enabled" --output tsv

# If you need to enable Workload Identity and/or the OIDC issuer, run the following command to enable them on your AKS cluster.

#  --name $AKS_NAME --enable-oidc-issuer --enable-workload-identity

# STEP 5: Get the OIDC Issuer URL
export AKS_OIDC_ISSUER="$(az aks show --resource-group $RG_NAME --name $AKS_NAME --query "oidcIssuerProfile.issuerUrl" --output tsv)"
echo $AKS_OIDC_ISSUER

# STEP 5: Create a Managed Identity
export USER_ASSIGNED_IDENTITY_NAME="myIdentity"

echo $USER_ASSIGNED_IDENTITY_NAME

az identity create --resource-group $RG_NAME \--name $USER_ASSIGNED_IDENTITY_NAME --location $LOCATION

# You will need several properties of the managed identity for the next steps. 
# Run the following commands to capture the details of the managed identity and save the values as environment variables.

export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group $RG_NAME --name $USER_ASSIGNED_IDENTITY_NAME --query "clientId" --output tsv)"
echo $USER_ASSIGNED_CLIENT_ID

export USER_ASSIGNED_PRINCIPAL_ID="$(az identity show --name "$USER_ASSIGNED_IDENTITY_NAME" --resource-group $RG_NAME --query "principalId" --output tsv)"
echo $USER_ASSIGNED_PRINCIPAL_ID

# STEP 6: Create a Kubernetes Service Account

export SERVICE_ACCOUNT_NAME="workload-identity-sa"
echo $SERVICE_ACCOUNT_NAME

# The service account namespace should be the same as the namespace where your application pods will be deployed
export SERVICE_ACCOUNT_NAMESPACE="default"
echo $SERVICE_ACCOUNT_NAMESPACE

# Run the following command to create the service account and annotate it with the client ID of the managed identity.

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF

# STEP 7: Create the Federated Identity Credential
export FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity"
echo $FEDERATED_IDENTITY_CREDENTIAL_NAME

# Run the following command to create the federated identity credential which creates a link between the managed identity, the service account issuer, and the subject.

az identity federated-credential create --name $FEDERATED_IDENTITY_CREDENTIAL_NAME --identity-name $USER_ASSIGNED_IDENTITY_NAME --resource-group $RG_NAME --issuer $AKS_OIDC_ISSUER --subject "system:serviceaccount:$SERVICE_ACCOUNT_NAMESPACE:$SERVICE_ACCOUNT_NAME" --audience api://AzureADTokenExchange

# Assign the Key Vault Secrets User role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault.

az role assignment create --assignee-object-id "$USER_ASSIGNED_PRINCIPAL_ID" --role "Key Vault Secrets User" --scope "$AKV_ID" --assignee-principal-type ServicePrincipal


# STEP 8: Deploy a Sample Application Utilizing Workload Identity

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sample-workload-identity
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"  # Required. Only pods with this label can use workload identity.
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: busybox
      name: busybox
      command: ["sh", "-c", "sleep 3600"]
EOF


# STEP 9: Access Secrets in Azure Key Vault with Workload Identity

# Run the following command to make sure the Azure account you are signed in on has the appropriate privileges to create secrets in an Azure Key Vault.
az role assignment create --assignee-object-id $(az ad signed-in-user show --query id -o tsv) --role "Key Vault Administrator" --scope "$AKV_ID" --assignee-principal-type User

# Next, run the following command to create a secret in the key vault.
az keyvault secret set --vault-name "$AKV_NAME" --name "my-secret" --value "Hello\!"

# STEP 10: Run the following command to deploy a pod that references the service account and key vault URL.

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
        value: $(az keyvault show -n ${AKV_NAME} -g ${RG_NAME} --query "properties.vaultUri" -o tsv)
      - name: SECRET_NAME
        value: my-secret
  nodeSelector:
    kubernetes.io/os: linux
EOF

# To check whether all properties are injected properly, use the kubectl describe command
kubectl describe pod sample-workload-identity-key-vault -n $SERVICE_ACCOUNT_NAMESPACE | grep "SECRET_NAME:"

# To verify that pod is able to get a token and access the resource, use the kubectl logs command:
kubectl logs -n $SERVICE_ACCOUNT_NAMESPACE sample-workload-identity-key-vault