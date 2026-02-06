# Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster using Terraform

Source: [Microsoft Learn](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-terraform?pivots=development-environment-azure-cli)

Azure Kubernetes Service (AKS) is a managed Kubernetes service that lets you quickly deploy and manage clusters. In this quickstart, you:

- Deploy an AKS cluster using Terraform.
- Run a sample multi-container application with a group of microservices and web front ends simulating a retail scenario.

> **Note:** To get started with quickly provisioning an AKS cluster, this article includes steps to deploy a cluster with default settings for evaluation purposes only. Before deploying a production-ready cluster, we recommend that you familiarize yourself with our [baseline reference architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/baseline-aks?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json) to consider how it aligns with your business requirements.

## Before you begin

- This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/concepts-clusters-workloads).
- You need an Azure account with an active subscription. If you don't have one, [create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- [Install and configure Terraform](https://learn.microsoft.com/en-us/azure/developer/terraform/quickstart-configure).
- [Download kubectl](https://kubernetes.io/releases/download/).

### Key Terraform Resources Used

- Create a random value for the Azure resource group name using [random_pet](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet).
- Create an Azure resource group using [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group).
- Access the configuration of the AzureRM provider to get the Azure Object ID using [azurerm_client_config](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config).
- Create a Kubernetes cluster using [azurerm_kubernetes_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster).
- Create an AzAPI resource [azapi_resource](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource).
- Create an AzAPI resource to generate an SSH key pair using [azapi_resource_action](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource_action).

### Important Notice

> **Important:** As of November 30, 2025, Azure Kubernetes Service (AKS) no longer supports or provides security updates for Azure Linux 2.0. The Azure Linux 2.0 node image is frozen at the [202512.06.0 release](https://raw.githubusercontent.com/Azure/AgentBaker/main/vhdbuilder/release-notes/AKSCBLMarinerV2/gen2/202512.06.0.txt). Beginning March 31, 2026, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [upgrading your node pools](https://learn.microsoft.com/en-us/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [osSku AzureLinux3](https://learn.microsoft.com/en-us/azure/aks/upgrade-os-version).

## Login to your Azure account

First, log into your Azure account and authenticate using one of the methods described in the following section.

> **Note:** Terraform only supports authenticating to Azure with the Azure CLI. Authenticating using Azure PowerShell isn't supported. Therefore, while you can use the Azure PowerShell module when doing your Terraform work, you first need to [authenticate to Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure).

## Implement the Terraform code

> **Note:** The sample code for this article is located in the [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/201-k8s-cluster-with-tf-and-aks). You can view the log file containing the [test results from current and previous versions of Terraform](https://github.com/Azure/terraform/tree/master/quickstart/201-k8s-cluster-with-tf-and-aks/TestRecord.md).

STEP 1

cd src/01AKSBasicsAndSetup


STEP 2

## Initialize Terraform

Run `terraform init` to initialize the Terraform deployment. This command downloads the Azure provider required to manage your Azure resources.

```bash
terraform init -upgrade
```

**Key points:**
- The `-upgrade` parameter upgrades the necessary provider plugins to the newest version that complies with the configuration's version constraints.

STEP 3

## Create a Terraform execution plan

Run `terraform plan` to create an execution plan.

```bash
terraform plan -out main.tfplan
```

**Key points:**
- The `terraform plan` command creates an execution plan, but doesn't execute it. Instead, it determines what actions are necessary to create the configuration specified in your configuration files. This pattern allows you to verify whether the execution plan matches your expectations before making any changes to actual resources.
- The optional `-out` parameter allows you to specify an output file for the plan. Using the `-out` parameter ensures that the plan you reviewed is exactly what is applied.


STEP 4

## Apply a Terraform execution plan

Run `terraform apply` to apply the execution plan to your cloud infrastructure.

```bash
terraform apply main.tfplan
```

**Key points:**
- The example `terraform apply` command assumes you previously ran `terraform plan -out main.tfplan`.
- If you specified a different filename for the `-out` parameter, use that same filename in the call to `terraform apply`.
- If you didn't use the `-out` parameter, call `terraform apply` without any parameters.


## Verify the results

STEP 5


### 1. Get the resource group name

```bash
resource_group_name=$(terraform output -raw resource_group_name)
echo ${resource_group_name}
```

STEP 6

### 2. Display the Kubernetes cluster name

```bash
az aks list \
  --resource-group $resource_group_name \
  --query "[].{\"K8s cluster name\":name}" \
  --output table
```

STEP 7

### 3. Get the Kubernetes configuration

Get the Kubernetes configuration from the Terraform state and store it in a file that `kubectl` can read:

```bash
echo "$(terraform output kube_config)" > ./azurek8s
```

STEP 8

### 4. Verify the configuration file

Verify the previous command didn't add an ASCII EOT character:

```bash
cat ./azurek8s
```

> **Important:** If you see `<< EOT` at the beginning and `EOT` at the end, remove these characters from the file. Otherwise, you may receive the following error message: `error: error loading config file "./azurek8s": yaml: line 2: mapping values are not allowed in this context`

STEP 9

### 5. Set the KUBECONFIG environment variable

```bash
export KUBECONFIG=./azurek8s
```

STEP 10

### 6. Verify the cluster health

```bash
kubectl get nodes
```

NOTE: You might get an error like:
error: error loading config file "./azurek8s": yaml: line 2: mapping values are not allowed in this context

If that is the case then remove the strings EOT from the azurek8s file and try again.


**Key points:**
- When you created the AKS cluster, monitoring was enabled to capture health metrics for both the cluster nodes and pods. These health metrics are available in the Azure portal. For more information on container health monitoring, see [Monitor Azure Kubernetes Service health](https://learn.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-overview).
- Several key values classified as output when you applied the Terraform execution plan. For example, the host address, AKS cluster user name, and AKS cluster password are output.

## Deploy the application

To deploy the application, you use a manifest file to create all the objects required to run the [AKS Store application](https://github.com/Azure-Samples/aks-store-demo). A Kubernetes manifest file defines a cluster's desired state, such as which container images to run. The manifest includes the following Kubernetes deployments and services:

![AKS Store Architecture](https://learn.microsoft.com/en-us/azure/aks/learn/media/quick-kubernetes-deploy-terraform/aks-store-architecture.png)

- **Store front**: Web application for customers to view products and place orders.
- **Product service**: Shows product information.
- **Order service**: Places orders.
- **Rabbit MQ**: Message queue for an order queue.

> **Note:** We don't recommend running stateful containers, such as Rabbit MQ, without persistent storage for production. These are used here for simplicity, but we recommend using managed services, such as Azure CosmosDB or Azure Service Bus.

STEP 11

### 1. Deploy the application

Deploy the application using the `kubectl apply` command and specify the name of your YAML manifest:

```bash
kubectl apply -f aks-store-quickstart.yaml
```

The following example output shows the deployments and services:

```
deployment.apps/rabbitmq created
service/rabbitmq created
deployment.apps/order-service created
service/order-service created
deployment.apps/product-service created
service/product-service created
deployment.apps/store-front created
service/store-front created
```

## Test the application

When the application runs, a Kubernetes service exposes the application front end to the internet. This process can take a few minutes to complete.

STEP 12

### 1. Check the pod status

```bash
kubectl get pods
```

Make sure all pods are `Running` before proceeding.

STEP 13

### 2. Monitor for the external IP address

```bash
kubectl get service store-front --watch
```

The EXTERNAL-IP output for the `store-front` service initially shows as pending:

```
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
store-front   LoadBalancer   10.0.100.10   <pending>     80:30025/TCP   4h4m
```

### 3. Wait for the IP address

Once the EXTERNAL-IP address changes from pending to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

```
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE
store-front   LoadBalancer   10.0.100.10   20.62.159.19   80:30025/TCP   4h5m
```

STEP 14

### 4. Browse to the application

Open a web browser to the external IP address of your service to see the Azure Store app in action.

![AKS Store Application](https://learn.microsoft.com/en-us/azure/aks/learn/media/quick-kubernetes-deploy-terraform/aks-store-application.png)

## Clean up resources

### Delete AKS resources

When you no longer need the resources created via Terraform, do the following steps:


STEP 15

#### 1. Create a destroy plan

```bash
terraform plan -destroy -out main.destroy.tfplan
```

**Key points:**
- The `terraform plan` command creates an execution plan, but doesn't execute it. Instead, it determines what actions are necessary to create the configuration specified in your configuration files. This pattern allows you to verify whether the execution plan matches your expectations before making any changes to actual resources.
- The optional `-out` parameter allows you to specify an output file for the plan. Using the `-out` parameter ensures that the plan you reviewed is exactly what is applied.


STEP 16

#### 2. Apply the destroy plan

```bash
terraform apply main.destroy.tfplan
```

STEP 17

### Delete service principal (if applicable)

If you created a service principal:

#### 1. Get the service principal ID

```bash
sp=$(terraform output -raw sp)
```

STEP 18

```bash
echo ${sp}
```

If the command's output is like the following then you can skip step 19

│ Warning: No outputs found │  │ The state file either has no outputs defined, ...


STEP 19

#### 2. Delete the service principal

```bash
az ad sp delete --id $sp
```

## Troubleshoot Terraform on Azure

[Troubleshoot common problems when using Terraform on Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/troubleshoot).

## Next steps

In this quickstart, you deployed a Kubernetes cluster and then deployed a simple multi-container application to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance on creating full solutions with AKS for production, see [AKS solution guidance](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks-start-here?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json).

To learn more about AKS and walk through a complete code-to-deployment example, continue to the Kubernetes cluster tutorial.

- [Learn more about using AKS](https://learn.microsoft.com/en-us/azure/aks)
- [Create an AKS cluster that supports Windows Server containers](https://learn.microsoft.com/en-us/azure/aks/learn/quick-windows-container-deploy-cli)

## Additional Resources

- [Kubernetes core concepts for Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/concepts-clusters-workloads)
- [AKS baseline reference architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/baseline-aks?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json)
- [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/201-k8s-cluster-with-tf-and-aks)

---

*Last updated: December 17, 2025*
