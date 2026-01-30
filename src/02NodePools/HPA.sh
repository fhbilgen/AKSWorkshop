
# STEP 1: Install the sample application
# This file is published in the repo: https://github.com/Azure-Samples/aks-store-demo
# The CPU request for the store-front container has been modified to 10m from 1m.
kubectl apply -f src/00AKSStoreApp/aks-store-quickstart.yaml 

# STEP 2: 
# Appy the following file to create the HPA for store-front deployment.
kubectl apply -f src/02NodePools/aks-store-quickstart-hpa.yaml 

# STEP 3: Check the status of the autoscaler using the kubectl get hpa command.
kubectl get hpa

# STEP 3B: Create a simplae Azure Load Test using the Azure portal.
# Use the store-front endpoint as the target URL.

# STEP 4: Start generating load to see the autoscaler in action.
# Start the load test from the Azure portal

# STEP 5: Run the following commands during the test to see the effect of the load test on the HPA.
kubectl get hpa store-front-hpa
kubectl get pods -l app=store-front
kubectl describe hpa store-front-hpa

# STEP 6: After the load test is complete, run the same comments to see how the HPA scales down.
kubectl get hpa store-front-hpa
kubectl get pods -l app=store-front
kubectl describe hpa store-front-hpa

