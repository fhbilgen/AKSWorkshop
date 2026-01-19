# Assume the clsuter from the SecretStoreCSIDriver lab is still there

# STEP 1: Create two namespaces test-restricted & test-privileged

kubectl create namespace test-restricted
kubectl create namespace test-privileged

# STEP 2: Enable a PSA policy for each namespace
kubectl label --overwrite ns test-restricted pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted
kubectl label --overwrite ns test-privileged pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/warn=privileged

# STEP 2A: Open the deployment YAML file and observe the security context settings
# https://github.com/Azure-Samples/azure-voting-app-redis/blob/master/azure-vote-all-in-one-redis.yaml

# STEP 3: Attempt to deploy pods to the test-restricted 
kubectl apply --namespace test-restricted -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml

# Confirm there are no pods running in the test-restricted
kubectl get pods --namespace test-restricted

# STEP 4: Attempt to deploy pods to the test-privileged
kubectl apply --namespace test-privileged -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml

# Confirm you have pods running in the test-privileged namespace 
kubectl get pods --namespace test-privileged

# STEP 5: Clean-up

# Delete resource group
echo "Deleting resource group"
az group delete --name myaks-rg --yes --no-wait