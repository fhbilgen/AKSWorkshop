# This lab is published at https://azure-samples.github.io/aks-labs/docs/networking/acns-lab/

# STEP 1: Setup Resources

export USER_ID=$(az ad signed-in-user show --query id -o tsv)

az deployment group create \
--resource-group ${RG_NAME} \
--name ${RG_NAME}-deployment \
--template-uri https://raw.githubusercontent.com/azure-samples/aks-labs/refs/heads/main/docs/getting-started/assets/aks-labs-deploy.json \
--parameters userObjectId=${USER_ID} \
--no-wait

az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingFlowLogsPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"


# STEP 2: Setup Resource Group

RAND=$RANDOM
export RAND
echo "Random resource identifier will be: ${RAND}"

export LOCATION=westus2
export RG_NAME=myresourcegroup$RAND

az group create \
--name ${RG_NAME} \
--location ${LOCATION}


# STEP 3: Setup AKS CLuster

export AKS_NAME=myakscluster$RAND

az aks create \
  --name ${AKS_NAME} \
  --resource-group ${RG_NAME} \
  --location ${LOCATION} \
  --pod-cidr 192.168.0.0/16 \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --generate-ssh-keys \
  --enable-container-network-logs \
  --enable-acns \
  --acns-advanced-networkpolicies L7 \
  --enable-addons monitoring \
  --enable-high-log-scale-mode


  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME"

  # STEP 4: Deploy the sample application

  # Create the pet store namespace
kubectl create ns pets

# Deploy the pet store components to the pets namespace
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml -n pets

kubectl get pods -n pets

# STEP 5: Enforcing Network Policy

# Test a connection to an external website from the order-service pod
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service -- sh -c 'wget --spider www.bing.com'

# Expected output
# Connecting to www.bing.com (13.107.21.237:80)
# remote file exists

# test the connection between the order-service and product-service pods which is allowed but not required by the architecture
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'nc -zv -w2 product-service 3002'

# Expected output
# product-service (10.0.96.101:3002) open

# In both tests, the connection was successful. This is because all traffic is allowed by default in Kubernetes.

# Deploy Network Policy
curl -o acns-network-policy.yaml https://raw.githubusercontent.com/Azure-Samples/aks-labs/refs/heads/main/docs/networking/assets/acns-network-policy.yaml

# Optional
# cat acns-network-policy.yaml

# Apply the policy
kubectl apply -n pets -f acns-network-policy.yaml

# View policies
kubectl get cnp -n pets

# test the connection to www.bing.com from the order-service pod.
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service -- sh -c 'wget --spider --timeout=1 --tries=1 www.bing.com'

# Expected output
# wget: bad address 'www.bing.com'
# command terminated with exit code 1

# test the connection between the order-service and product-service pods
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'nc -zv -w2 product-service 3002'

# Expected output:
# nc: bad address 'product-service'
# command terminated with exit code 1

# STEP 6: Configuring FQDN Filtering

# test the connection to the Microsoft Graph API from the order-service pod.
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'wget --spider --timeout=1 --tries=1 https://graph.microsoft.com'

# Expected output: the traffic is denied
# This is an expected behavior because we have implemented zero trust security policy and denying any unwanted traffic.

# Create an FQDN Policy
# To limit egress to certain domains, apply an FQDN policy
# Note: FQDN filtering requires ACNS to be enabled

curl -o acns-network-policy-fqdn.yaml https://raw.githubusercontent.com/Azure-Samples/aks-labs/refs/heads/main/docs/networking/assets/acns-network-policy-fqdn.yaml

# Take a look at the FQDN policy manifest file 
cat acns-network-policy-fqdn.yaml

# Apply the FQDN policy to the pets namespace
kubectl apply -n pets -f acns-network-policy-fqdn.yaml

# Verify FQDN Policy Enforcement
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'wget --spider --timeout=1 --tries=1 https://graph.microsoft.com'

# Expected output
# Connecting to graph.microsoft.com (20.190.152.88:443)
# Connecting to developer.microsoft.com (23.45.149.11:443)
# Connecting to developer.microsoft.com (23.45.149.11:443)
# remote file exists


##############################################################################################################
# Monitoring Advanced Network Metrics and Flows

# Run the following command to download the chaos policy manifest file
