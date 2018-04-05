set -e

echo "Starting test for acsengine-orchestrator-dvm."
date

echo "Running as:"
whoami

sleep 20

# Script parameters
BUILD_ACS_ENGINE=${1}
API_MODEL_PATH=${2}
TENANT_ID=${3}
TENANT_SUBSCRIPTION_ID=${4}
TENANT_USERNAME=${5}
TENANT_PASSWORD=${6}
AZS_SA_NAME=${7}
AZS_SA_RESOURCE_GROUP=${8}
K8S_AZURE_CLOUDPROVIDER_VERSION=${9}
REGION_NAME=${10}

echo "BUILD_ACS_ENGINE: $BUILD_ACS_ENGINE"
echo "API_MODEL_PATH: $API_MODEL_PATH"
echo "TENANT_ID: $TENANT_ID"
echo "TENANT_SUBSCRIPTION_ID: $TENANT_SUBSCRIPTION_ID"
echo "TENANT_USERNAME: $TENANT_USERNAME"
echo "AZS_SA_NAME: $AZS_SA_NAME"
echo "AZS_SA_RESOURCE_GROUP: $AZS_SA_RESOURCE_GROUP"
echo "K8S_AZURE_CLOUDPROVIDER_VERSION: $K8S_AZURE_CLOUDPROVIDER_VERSION"
echo "REGION_NAME: $REGION_NAME"

echo 'Printing the system information'
sudo uname -a

echo "Update the system."
sudo apt-get update -y

echo "Install AzureCLI."
# See: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest#install-on-debianubuntu-with-apt-get
apt-get update -y
apt-get install apt-transport-https -y
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" > /etc/apt/sources.list.d/azure-cli.list
apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
apt-get update -y
apt-get install azure-cli -y

echo 'Import the root CA certificate to python store.'
PYTHON_CERTIFI_LOCATION=$(python -c "import certifi; print(certifi.where())")
sudo cat /var/lib/waagent/Certificates.pem >> $PYTHON_CERTIFI_LOCATION

echo 'Import the root CA to store.'
sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azsCertificate.crt
update-ca-certificates

echo 'Retrieve the AzureStack root CA certificate thumbprint'
THUMBPRINT=$(openssl x509 -in /var/lib/waagent/Certificates.pem -fingerprint -noout | cut -d'=' -f 2 | tr -d :)
echo 'Thumbprint for AzureStack root CA certificate:' $THUMBPRINT

echo "Clone the ACS-Engine repo"
git clone https://github.com/msazurestackworkloads/acs-engine -b acs-engine-v0140
cd acs-engine

if [ $BUILD_ACS_ENGINE == "True" ]
then
    echo "We are going to build ACS-Engine."

	echo "Install docker"
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update -y
    sudo apt-get install docker-ce -y

    echo "Install Make."
    sudo apt-get install make -y

    echo "Build developer environment."
    sudo make devenv

    echo "Build the repository."
    sudo make all

	exit
else
    echo "We are going to use an existing ACS-Engine binary."

    echo "Open the zip file from the repo location."
    sudo mkdir bin
    sudo tar -zxvf examples/azurestack/acs-engine.tgz
    sudo mv acs-engine bin/
fi

echo "Printing help for acs-engine to ensure that binary is available."
sudo ./bin/acs-engine --help

echo "Download the API model."
sudo wget $API_MODEL_PATH --no-check-certificate

echo "Installing pax for string manipulation."
sudo apt-get install pax -y

echo "Installing jq for JSON manipulation."
apt-get install jq -y

FILE_NAME=$(basename $API_MODEL_PATH)
echo "File name is: $FILE_NAME"

AZS_SA_CONTAINER_NAME=$(basename $(dirname $API_MODEL_PATH))
echo "AzureStack container name is: $AZS_SA_CONTAINER_NAME"

MASTER_DNS_PREFIX=$(jq '.properties.masterProfile.dnsPrefix' $FILE_NAME | tr -d \")
TENANT_ENDPOINT=$(jq '.properties.cloudProfile.resourceManagerEndpoint' $FILE_NAME | tr -d \")
STORAGE_ENDPOINT_SUFFIX=$(jq '.properties.cloudProfile.storageEndpointSuffix' $FILE_NAME | tr -d \")
KEYVAULT_DNS_SUFFIX=".$(jq '.properties.cloudProfile.keyVaultDNSSuffix' $FILE_NAME | tr -d \")"
GRAPH_ENDPOINT=$(jq '.properties.cloudProfile.graphEndpoint' $FILE_NAME | tr -d \")
REGION=$(jq '.properties.cloudProfile.location' $FILE_NAME | tr -d \")
SPNCLIENTID=$(jq '.properties.servicePrincipalProfile.clientId' $FILE_NAME | tr -d \")
SPNSECRET=$(jq '.properties.servicePrincipalProfile.secret' $FILE_NAME | tr -d \")

ENVIRONMENT_NAME=AzureStackCloud
echo 'Register to the cloud.'
az cloud register \
  --name $ENVIRONMENT_NAME \
  --endpoint-resource-manager $TENANT_ENDPOINT

az cloud set --name $ENVIRONMENT_NAME

# Override the default file with the correct values.
sudo cp examples/azurestack/azurestack-kubernetes$K8S_AZURE_CLOUDPROVIDER_VERSION.json azurestack.json
if [ ! azurestack.json ]
then
  echo "File does not exist. Exiting..."
  exit 1
fi

sudo cat azurestack.json | jq --arg THUMBPRINT $THUMBPRINT '.properties.cloudProfile.resourceManagerRootCertificate = $THUMBPRINT' | \
jq --arg REGION_NAME $REGION_NAME '.properties.cloudProfile.location = $REGION_NAME' > azurestack_temp.json

sudo mv azurestack_temp.json azurestack.json

echo 'Login to the cloud.'
az login \
  --username $TENANT_USERNAME \
  --password $TENANT_PASSWORD \
  --tenant $TENANT_ID

az account set --subscription $TENANT_SUBSCRIPTION_ID

MYDIR=$PWD
echo "Current directory is: $MYDIR"

echo "Generate and Deploy the template using the API model in resource group $MASTER_DNS_PREFIX."
sudo ./bin/acs-engine deploy --resource-group $MASTER_DNS_PREFIX --azure-env $ENVIRONMENT_NAME --location $REGION --subscription-id $TENANT_SUBSCRIPTION_ID --client-id $SPNCLIENTID --client-secret $SPNSECRET --auth-method client_secret --api-model $FILE_NAME

echo "Accessing the generated templates."
sudo chmod 777 -R _output/
cd _output/

echo 'Get connection string to upload the templates to a storage account.'
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AZS_SA_NAME --resource-group $AZS_SA_RESOURCE_GROUP --query connectionString)
export AZURE_STORAGE_ACCOUNT=$AZS_SA_NAME

echo "AZURE_STORAGE_CONNECTION_STRING: $AZURE_STORAGE_CONNECTION_STRING"
echo "AZURE_STORAGE_ACCOUNT: $AZURE_STORAGE_ACCOUNT"

echo "Uploading templates to the storage account: $AZURE_STORAGE_ACCOUNT, Container: $AZS_SA_CONTAINER_NAME from _output/$MASTER_DNS_PREFIX"
az storage blob upload \
  --container-name $AZS_SA_CONTAINER_NAME \
  --name "$MASTER_DNS_PREFIX/azuredeploy.json" \
  --file "$MYDIR/_output/$MASTER_DNS_PREFIX/azuredeploy.json"

az storage blob upload \
  --container-name $AZS_SA_CONTAINER_NAME \
  --name "$MASTER_DNS_PREFIX/azuredeploy.parameters.json" \
  --file "$MYDIR/_output/$MASTER_DNS_PREFIX/azuredeploy.parameters.json"

echo "Ending test for acsengine-orchestrator-dvm."



