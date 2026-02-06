# Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster using Azure CLI

- Deploy an AKS cluster using the Azure CLI
- Run a sample multi-container application with a group of microservices and web front ends that simulate a retail scenario

> **Note:** This article includes steps to deploy a cluster with default settings for evaluation purposes only. Before you deploy a production-ready cluster, we recommend that you familiarize yourself with our baseline reference architecture to consider how it aligns with your business requirements.

## Before you begin

This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see Kubernetes core concepts for Azure Kubernetes Service (AKS).

### Prerequisites

- If you don't have an Azure account, create a free account before you begin
- Use the Bash environment in Azure Cloud Shell, or
- If you prefer to run CLI reference commands locally, install the Azure CLI. If you're running on Windows or macOS, consider running Azure CLI in a Docker container
  - If you're using a local installation, sign in to the Azure CLI by using the `az login` command
  - When you're prompted, install the Azure CLI extension on first use
  - Run `az version` to find the version and dependent libraries that are installed. To upgrade to the latest version, run `az upgrade`
- Make sure that the identity you're using to create your cluster has the appropriate minimum permissions. For more information on access and identity for AKS, see Access and identity options for Azure Kubernetes Service (AKS)
- If you have multiple Azure subscriptions, select the appropriate subscription ID in which the resources should be billed using the `az account set` command
- Dependent upon your Azure subscription, you might need to request a vCPU quota increase. For more information, see Increase VM-family vCPU quotas

## Register resource providers

You might need to register resource providers in your Azure subscription. For example, `Microsoft.ContainerService` is required.

Run the following command to check the registration status:

STEP 1
```bash
az provider show --namespace Microsoft.ContainerService --query registrationState
```

If necessary, register the resource provider:
STEP 2: OPTIONAL
```bash
az provider register --namespace Microsoft.ContainerService
```

## Define environment variables

Define the following environment variables for use throughout this quickstart:

STEP 3
```bash
export RANDOM_ID="$(openssl rand -hex 3)"
export MY_RESOURCE_GROUP_NAME="myAKSResourceGroup$RANDOM_ID"
export REGION="westus2"
export MY_AKS_CLUSTER_NAME="myAKSCluster$RANDOM_ID"
export MY_DNS_LABEL="mydnslabel$RANDOM_ID"
```
STEP 4

Test the value of the environment variables
```bash
echo ${MY_RESOURCE_GROUP_NAME} ${REGION} ${MY_AKS_CLUSTER_NAME} ${MY_DNS_LABEL}
```

The `RANDOM_ID` variable's value is a six character alphanumeric value appended to the resource group and cluster name so that the names are unique. Use the `echo` command to view variable values like `echo $RANDOM_ID`.

## Create a resource group

An Azure resource group is a logical group in which Azure resources are deployed and managed. When you create a resource group, you're prompted to specify a location. This location is the storage location of your resource group metadata and where your resources run in Azure if you don't specify another region during resource creation.

STEP 5
Create a resource group using the `az group create` command:

```bash
az group create --name $MY_RESOURCE_GROUP_NAME --location $REGION
```

The result looks like the following example:

```json
{
  "id": "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/myAKSResourceGroup<randomIDValue>",
  "location": "westus",
  "managedBy": null,
  "name": "myAKSResourceGroup<randomIDValue>",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

## Create an AKS cluster

STEP 6

Create an AKS cluster using the `az aks create` command. The following example creates a cluster with one node and enables a system-assigned managed identity:

```bash
az aks create \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --name $MY_AKS_CLUSTER_NAME \
  --node-count 1 \
  --generate-ssh-keys
```

> **Note:** When you create a new cluster, AKS automatically creates a second resource group to store the AKS resources. For more information, see Why are two resource groups created with AKS?

## Connect to the cluster

To manage a Kubernetes cluster, use the Kubernetes command-line client, `kubectl`. `kubectl` is already installed if you use Azure Cloud Shell. To install `kubectl` locally, use the `az aks install-cli` command.

STEP 7

1. Configure `kubectl` to connect to your Kubernetes cluster using the `az aks get-credentials` command. This command downloads credentials and configures the Kubernetes CLI to use them:

```bash
az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME
```
STEP 8

2. Verify the connection to your cluster using the `kubectl get` command. This command returns a list of the cluster nodes:

```bash
kubectl get nodes
```

NOTE: If the kubectl command does not show the expected result then you may want to check the value of the KUBECONFIG env variable.

echo ${KUBECONFIG} 

If it is empty then try to set to the path which you can copy from the output of the az aks get-credentials command output.
e.g. 
Merged "myAKSClusterf911c1" as current context in C:\Users\USERNAME\.kube\config

then set the env variable's value to that path
export KUBECONFIG=/mnt/c/Users/USERNAME/.kube/config

Repeat the command 

kubectl get node

END-OF-NOTE

## Deploy the application

To deploy the application, you use a manifest file to create all the objects required to run the AKS Store application. A Kubernetes manifest file defines a cluster's desired state, such as which container images to run. The manifest includes the following Kubernetes deployments and services:

- **Store front**: Web application for customers to view products and place orders
- **Product service**: Shows product information
- **Order service**: Places orders
- **RabbitMQ**: Message queue for an order queue

> **Note:** We don't recommend running stateful containers, such as RabbitMQ, without persistent storage for production. We use it here for simplicity, but we recommend using managed services, such as Azure CosmosDB or Azure Service Bus.

### Steps:

STEP 9

Apply the file named `aks-store-quickstart.yaml` 
```bash
 kubectl apply -f src/01AKSBasicsAndSetup/aks-store-quickstart.yaml 
```

## Test the application

You can validate that the application is running by visiting the public IP address or the application URL.

STEP 10
Get the application URL using the following commands:

```bash
runtime="5 minutes"
endtime=$(date -ud "$runtime" +%s)
while [[ $(date -u +%s) -le $endtime ]]
do
   STATUS=$(kubectl get pods -l app=store-front -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}')
   echo $STATUS
   if [ "$STATUS" == 'True' ]
   then
      export IP_ADDRESS=$(kubectl get service store-front --output 'jsonpath={..status.loadBalancer.ingress[0].ip}')
      echo "Service IP Address: $IP_ADDRESS"
      break
   else
      sleep 10
   fi
done
```
STEP 11
Test the application:

```bash
curl $IP_ADDRESS
```

Expected output:

```html
<!doctype html>
<html lang="">
   <head>
      <meta charset="utf-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <link rel="icon" href="/favicon.ico">
      <title>store-front</title>
      <script defer="defer" src="/js/chunk-vendors.df69ae47.js"></script>
      <script defer="defer" src="/js/app.7e8cfbb2.js"></script>
      <link href="/css/app.a5dc49f6.css" rel="stylesheet">
   </head>
   <body>
      <div id="app"></div>
   </body>
</html>
```

STEP 12

Display the IP address:

```bash
echo "You can now visit your web server at $IP_ADDRESS"
```

To view the application website, open a browser and enter the IP address.

STEP 13

## Delete the cluster

If you don't plan on going through the AKS tutorial, clean up unnecessary resources to avoid Azure billing charges. You can remove the resource group, container service, and all related resources using the `az group delete` command:

```bash
az group delete --name $MY_RESOURCE_GROUP_NAME
```

The AKS cluster was created with a system-assigned managed identity, which is the default identity option used in this quickstart. The platform manages this identity so you don't need to manually remove it.

## Next steps

In this quickstart, you deployed a Kubernetes cluster and then deployed a simple multi-container application to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance about how to create full solutions with AKS for production, see AKS solution guidance.

To learn more about AKS and do a complete code-to-deployment example, continue to the Kubernetes cluster tutorial.

---

**Source:** [Microsoft Learn - Quick Kubernetes Deploy CLI](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli)  
**Last updated:** August 19, 2025
