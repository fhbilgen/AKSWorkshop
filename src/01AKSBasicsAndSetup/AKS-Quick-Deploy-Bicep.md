# Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster using Bicep

Azure Kubernetes Service (AKS) is a managed Kubernetes service that lets you quickly deploy and manage clusters. In this quickstart, you:

- Deploy an AKS cluster using Bicep
- Run a sample multi-container application with a group of microservices and web front ends simulating a retail scenario

> **Note:** To get started with quickly provisioning an AKS cluster, this article includes steps to deploy a cluster with default settings for evaluation purposes only. Before deploying a production-ready cluster, we recommend that you familiarize yourself with our baseline reference architecture to consider how it aligns with your business requirements.

## Before you begin

### Prerequisites

- This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see Kubernetes core concepts for Azure Kubernetes Service (AKS)
- You need an Azure account with an active subscription. If you don't have one, create an account for free
- To learn more about creating a Windows Server node pool, see Create an AKS cluster that supports Windows Server containers
- Bicep is a domain-specific language (DSL) that uses declarative syntax to deploy Azure resources. It provides concise syntax, reliable type safety, and support for code reuse. Bicep offers the best authoring experience for your infrastructure-as-code solutions in Azure

### Azure CLI Requirements

- Use the Bash environment in Azure Cloud Shell, or
- If you prefer to run CLI reference commands locally, install the Azure CLI. If you're running on Windows or macOS, consider running Azure CLI in a Docker container
  - If you're using a local installation, sign in to the Azure CLI by using the `az login` command
  - When you're prompted, install the Azure CLI extension on first use
  - Run `az version` to find the version and dependent libraries that are installed. To upgrade to the latest version, run `az upgrade`
- This article requires Azure CLI version 2.0.64 or later. If you're using Azure Cloud Shell, the latest version is already installed there
- This article requires an existing Azure resource group. If you need to create one, you can use the `az group create` command
- To create an AKS cluster using a Bicep file, you provide an SSH public key. If you need this resource, see the following section
- Make sure that the identity you use to create your cluster has the appropriate minimum permissions. For more details on access and identity for AKS, see Access and identity options for Azure Kubernetes Service (AKS)
- To deploy a Bicep file, you need write access on the resources you create and access to all operations on the `Microsoft.Resources/deployments` resource type. For example, to create a virtual machine, you need `Microsoft.Compute/virtualMachines/write` and `Microsoft.Resources/deployments/*` permissions. For a list of roles and permissions, see Azure built-in roles

STEP 1
```bash
az provider show --namespace Microsoft.ContainerService --query registrationState
```

If necessary, register the resource provider:
STEP 2: OPTIONAL
```bash
az provider register --namespace Microsoft.ContainerService
```

STEP 3

az group create --name aks-bicep-rg --location westus2

STEP 4
### Create an SSH key pair

1. Go to [https://shell.azure.com](https://shell.azure.com/) to open Cloud Shell in your browser

2. Create an SSH key pair using the `az sshkey create` Azure CLI command or the `ssh-keygen` command:

```bash
# Create an SSH key pair using Azure CLI
az sshkey create --name "mySSHKey" --resource-group aks-bicep-rg

STEP 5
# Create an SSH key pair using ssh-keygen
ssh-keygen -t rsa -b 4096
```

NOTE: Know there should be two files: aks-bicep and aks-bicep.pub in the working folder !!!

For more information about creating SSH keys, see Create and manage SSH keys for authentication in Azure.

## Review the Bicep file

The Bicep file used in this quickstart is from Azure Quickstart Templates.

main.bicep

The resource defined in the Bicep file:

- **Microsoft.ContainerService/managedClusters**

For more AKS samples, see the AKS quickstart templates site.

## Deploy the Bicep file

1. Save the Bicep file as `main.bicep` to your local computer

> **Important:** The Bicep file sets the `clusterName` param to the string `aks101cluster`. If you want to use a different cluster name, make sure to update the string to your preferred cluster name before saving the file to your computer.

STEP 6

2. Deploy the Bicep file using Azure CLI:

```bash
az deployment group create --resource-group myResourceGroup --template-file main.bicep --parameters dnsPrefix=<dns-prefix> linuxAdminUsername=<linux-admin-username> sshRSAPublicKey='<ssh-key>'
```

better version is:
```bash
az deployment group create \
  --resource-group aks-bicep-rg \
  --template-file ./src/01AKSBasicsAndSetup/main.bicep \
  --parameters clusterName=aks101cluster \
               dnsPrefix=aks101cluster \
               linuxAdminUsername=azureuser \
               sshRSAPublicKey="$(cat aks-bicep.pub | tr -d '\n\r')"
```

Provide the following values in the command:

- **DNS prefix**: Enter a unique DNS prefix for your cluster, such as `myakscluster`
- **Linux Admin Username**: Enter a username to connect using SSH, such as `azureuser`
- **SSH RSA Public Key**: Copy and paste the public part of your SSH key pair (by default, the contents of `~/.ssh/id_rsa.pub`)

It takes a few minutes to create the AKS cluster. Wait for the cluster to be successfully deployed before you move on to the next step.

## Validate the Bicep deployment

### Connect to the cluster

To manage a Kubernetes cluster, use the Kubernetes command-line client, `kubectl`. `kubectl` is already installed if you use Azure Cloud Shell.

1. Install `kubectl` locally using the `az aks install-cli` command:

```bash
az aks install-cli
```

STEP 7

2. Configure `kubectl` to connect to your Kubernetes cluster using the `az aks get-credentials` command. This command downloads credentials and configures the Kubernetes CLI to use them:

```bash
az aks get-credentials --resource-group aks-bicep-rg --name aks101cluster
```

STEP 8

3. Verify the connection to your cluster using the `kubectl get` command. This command returns a list of the cluster nodes:

```bash
kubectl get nodes
```

The following example output shows the nodes created in the previous steps. Make sure the node status is Ready:

```output
NAME                       STATUS   ROLES   AGE     VERSION
aks-agentpool-41324942-0   Ready    agent   6m44s   v1.12.6
aks-agentpool-41324942-1   Ready    agent   6m46s   v1.12.6
aks-agentpool-41324942-2   Ready    agent   6m45s   v1.12.6
```

## Deploy the application

To deploy the application, you use a manifest file to create all the objects required to run the AKS Store application. A Kubernetes manifest file defines a cluster's desired state, such as which container images to run. The manifest includes the following Kubernetes deployments and services:

- **Store front**: Web application for customers to view products and place orders
- **Product service**: Shows product information
- **Order service**: Places orders
- **Rabbit MQ**: Message queue for an order queue

> **Note:** We don't recommend running stateful containers, such as Rabbit MQ, without persistent storage for production. These are used here for simplicity, but we recommend using managed services, such as Azure CosmosDB or Azure Service Bus.

### Steps:

1. Create a file named `aks-store-quickstart.yaml` and copy in the following manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: rabbitmq
        image: mcr.microsoft.com/mirror/docker/library/rabbitmq:3.10-management-alpine
        ports:
        - containerPort: 5672
          name: rabbitmq-amqp
        - containerPort: 15672
          name: rabbitmq-http
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: "username"
        - name: RABBITMQ_DEFAULT_PASS
          value: "password"
        resources:
          requests:
            cpu: 10m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        volumeMounts:
        - name: rabbitmq-enabled-plugins
          mountPath: /etc/rabbitmq/enabled_plugins
          subPath: enabled_plugins
      volumes:
      - name: rabbitmq-enabled-plugins
        configMap:
          name: rabbitmq-enabled-plugins
          items:
          - key: rabbitmq_enabled_plugins
            path: enabled_plugins
---
apiVersion: v1
data:
  rabbitmq_enabled_plugins: |
    [rabbitmq_management,rabbitmq_prometheus,rabbitmq_amqp1_0].
kind: ConfigMap
metadata:
  name: rabbitmq-enabled-plugins
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
spec:
  selector:
    app: rabbitmq
  ports:
    - name: rabbitmq-amqp
      port: 5672
      targetPort: 5672
    - name: rabbitmq-http
      port: 15672
      targetPort: 15672
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: order-service
        image: ghcr.io/azure-samples/aks-store-demo/order-service:latest
        ports:
        - containerPort: 3000
        env:
        - name: ORDER_QUEUE_HOSTNAME
          value: "rabbitmq"
        - name: ORDER_QUEUE_PORT
          value: "5672"
        - name: ORDER_QUEUE_USERNAME
          value: "username"
        - name: ORDER_QUEUE_PASSWORD
          value: "password"
        - name: ORDER_QUEUE_NAME
          value: "orders"
        - name: FASTIFY_ADDRESS
          value: "0.0.0.0"
        resources:
          requests:
            cpu: 1m
            memory: 50Mi
          limits:
            cpu: 75m
            memory: 128Mi
      initContainers:
      - name: wait-for-rabbitmq
        image: busybox
        command: ['sh', '-c', 'until nc -zv rabbitmq 5672; do echo waiting for rabbitmq; sleep 2; done;']
        resources:
          requests:
            cpu: 1m
            memory: 50Mi
          limits:
            cpu: 75m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 3000
    targetPort: 3000
  selector:
    app: order-service
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: product-service
        image: ghcr.io/azure-samples/aks-store-demo/product-service:latest
        ports:
        - containerPort: 3002
        resources:
          requests:
            cpu: 1m
            memory: 1Mi
          limits:
            cpu: 1m
            memory: 7Mi
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 3002
    targetPort: 3002
  selector:
    app: product-service
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: store-front
spec:
  replicas: 1
  selector:
    matchLabels:
      app: store-front
  template:
    metadata:
      labels:
        app: store-front
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: store-front
        image: ghcr.io/azure-samples/aks-store-demo/store-front:latest
        ports:
        - containerPort: 8080
          name: store-front
        env:
        - name: VUE_APP_ORDER_SERVICE_URL
          value: "http://order-service:3000/"
        - name: VUE_APP_PRODUCT_SERVICE_URL
          value: "http://product-service:3002/"
        resources:
          requests:
            cpu: 1m
            memory: 200Mi
          limits:
            cpu: 1000m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: store-front
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: store-front
  type: LoadBalancer
```

> For a breakdown of YAML manifest files, see Deployments and YAML manifests.
> 
> If you create and save the YAML file locally, then you can upload the manifest file to your default directory in CloudShell by selecting the Upload/Download files button and selecting the file from your local file system.

2. Deploy the application using the `kubectl apply` command and specify the name of your YAML manifest:

STEP 9

```bash
kubectl apply -f src/01AKSBasicsAndSetup/aks-store-quickstart.yaml 
```

The following example output shows the deployments and services:

```output
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

STEP 10

1. Check the status of the deployed pods using the `kubectl get pods` command. Make all pods are `Running` before proceeding:

```bash
kubectl get pods
```

2. Check for a public IP address for the store-front application. Monitor progress using the `kubectl get service` command with the `--watch` argument:

STEP 11

```bash
kubectl get service store-front --watch
```

The EXTERNAL-IP output for the `store-front` service initially shows as pending:

```output
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
store-front   LoadBalancer   10.0.100.10   <pending>     80:30025/TCP   4h4m
```

3. Once the EXTERNAL-IP address changes from pending to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

The following example output shows a valid public IP address assigned to the service:

```output
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE
store-front   LoadBalancer   10.0.100.10   20.62.159.19   80:30025/TCP   4h5m
```

STEP 12

4. Open a web browser to the external IP address of your service to see the Azure Store app in action.

## Delete the cluster

If you don't plan on going through the AKS tutorial, clean up unnecessary resources to avoid Azure charges.

Remove the resource group, container service, and all related resources using the `az group delete` command:

STEP 13

```bash
az group delete --name aks-bicep-rg --yes --no-wait
```

STEP 14

Delete the key files. Delete the aks-bicep and aks-bicep.pub files 

```bash
rm aks-bicep aks-bicep.pub 
```


> **Note:** The AKS cluster was created with a system-assigned managed identity, which is the default identity option used in this quickstart. The platform manages this identity so you don't need to manually remove it.

## Next steps

In this quickstart, you deployed a Kubernetes cluster and then deployed a simple multi-container application to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance on creating full solutions with AKS for production, see AKS solution guidance.

To learn more about AKS and walk through a complete code-to-deployment example, continue to the Kubernetes cluster tutorial.

---

**Source:** [Microsoft Learn - Quick Kubernetes Deploy Bicep](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-bicep?tabs=azure-cli)  
**Last updated:** August 1, 2024
