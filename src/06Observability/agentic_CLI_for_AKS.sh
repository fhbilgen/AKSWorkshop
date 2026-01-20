# Assuming the cluster for the AKS Advanced Observability Concepts is already created

# STEP 1: Install the agentic CLI for AKS extension
# Add the agentic CLI for AKS extension to your Azure CLI installation 
# Install the extension
az extension add --name aks-agent --debug

# Update the extension
az extension update --name aks-agent --debug

# Your output should include an entry for aks-agent
az extension list

# Verify that the extension is installed
az aks agent --help

# Initialize the agentic CLI for AKS
az aks agent-init --resource-group aksmon-rg --name aksmon 