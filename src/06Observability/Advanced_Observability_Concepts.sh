# STEP 1: AKS control plane metrics
az feature register --namespace "Microsoft.ContainerService" --name "AzureMonitorMetricsControlPlanePreview"

# Refresh the resource provider
az provider register --namespace Microsoft.ContainerService

# STEP 2: Setup environment variables

export RG_NAME="aksmon-rg"
export LOCATION="westus2"

# Azure Kubernetes Service Cluster
export AKS_CLUSTER_NAME="aksmon"

# Azure Managed Grafana
export GRAFANA_NAME="aks-mon-graf-${RANDOM}"

# Azure Monitor Workspace
export AZ_MONITOR_WORKSPACE_NAME="aksmon-wks"

# STEP 3: Create the Azure Monitor Workspace
# Create resource group
az group create --name ${RG_NAME} --location ${LOCATION}

# Create an Azure Monitor Workspace
az monitor account create --resource-group $RG_NAME --location $LOCATION --name $AZ_MONITOR_WORKSPACE_NAME

# Retrieve the Azure Monitor Workspace ID
export AZ_MONITOR_WORKSPACE_ID=$(az monitor account show --resource-group $RG_NAME --name $AZ_MONITOR_WORKSPACE_NAME --query id -o tsv)

# STEP 4: Create an Azure Managed Grafana instance
# Add the Azure Manage Grafana extension to az cli
az extension add --name amg

# Create an Azure Managed Grafana instance
az grafana create --name $GRAFANA_NAME --resource-group $RG_NAME --location $LOCATION

# Save the Grafana resource ID
export GRAFANA_RESOURCE_ID=$(az grafana show --name $GRAFANA_NAME --resource-group $RG_NAME --query id -o tsv)

# STEP 5: Create an AKS Cluster
# Create a new AKS cluster and attach the Grafana instance to it
az aks create --name $AKS_CLUSTER_NAME --resource-group $RG_NAME  --node-count 1 --enable-managed-identity --enable-azure-monitor-metrics --enable-cost-analysis --grafana-resource-id $GRAFANA_RESOURCE_ID --azure-monitor-workspace-resource-id $AZ_MONITOR_WORKSPACE_ID --tier Standard

# Get the credentials to access the cluster
az aks get-credentials --name $AKS_CLUSTER_NAME --resource-group $RG_NAME

# Check the credentails are working
kubectl cluster-info
kubectl get nodes

# STEP 6: Working on Grafana
# Create a folder in Grafana to host our new dashboards
az grafana folder create --name $GRAFANA_NAME --title AKS-Mon --resource-group $RG_NAME

# import kube-apiserver dashboard
az grafana dashboard import --name $GRAFANA_NAME --resource-group $RG_NAME --folder 'AKS-Mon' --definition 20331

# import etcd dashboard
az grafana dashboard import --name $GRAFANA_NAME --resource-group $RG_NAME --folder 'AKS-Mon' --definition 20330

# To access the Grafana Dashboard
GRAFANA_UI=$(az grafana show --name $GRAFANA_NAME --resource-group $RG_NAME --query "properties.endpoint" -o tsv)

echo "Your Azure Managed Grafana is accessible at: $GRAFANA_UI"

az grafana show --name $GRAFANA_NAME --resource-group $RG_NAME --query "properties.endpoint" -o tsv

# Browse the dashboard as described at https://azure-samples.github.io/aks-labs/docs/operations/observability-and-monitoring/#working-on-grafana

# STEP 7: Deploying the AKS Store Demo Application
# Do it before Example: Customizing the collection of metrics in the Lab document !!!
# https://azure-samples.github.io/aks-labs/docs/getting-started/setting-up-lab-environment#deploying-the-aks-store-demo-application

# Create a namespace for the application
kubectl create namespace pets

# Install the AKS Store Demo application
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/refs/heads/main/aks-store-quickstart.yaml -n pets

# Verify the application was installed
kubectl get all -n pets

# get the storefront service IP address
kubectl get svc store-front -n pets

# STEP 8: Example: Customizing the collection of metrics

# deploy the ama-metrics-settings-configmap in the kube-system namespace
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml

# Edit the ama-metrics-settings-configmap to enable the metrics you want to collect.
kubectl edit cm ama-metrics-settings-configmap -n kube-system

# Then continue from the LAB article

# STEP 9: Deploying a PodMonitor and a Sample Application

# Deploy a reference app
# https://github.com/Azure/prometheus-collector/blob/main/internal/referenceapp/prometheus-reference-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/internal/referenceapp/prometheus-reference-app.yaml

# Verify it's running
kubectl get pods,svc -l app=prometheus-reference-app

#  Deploy a PodMonitor
# https://github.com/Azure/prometheus-collector/blob/main/otelcollector/deploy/example-custom-resources/pod-monitor/pod-monitor-reference-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/deploy/example-custom-resources/pod-monitor/pod-monitor-reference-app.yaml

# Get the AMA Prometheus pod name
AMA_METRICS_POD_NAME="$(kubectl get po -n kube-system -lrsName=ama-metrics -o jsonpath='{.items[0].metadata.name}')"

# Port-forward Prometheus locally
kubectl port-forward ${AMA_METRICS_POD_NAME} -n kube-system 9090

# Open your browser at: http://localhost:9090
# Then continue from the LAB article

