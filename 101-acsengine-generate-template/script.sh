set -e

echo "Starting test for acsengine-generate-template."
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

echo "BUILD_ACS_ENGINE: $BUILD_ACS_ENGINE"
echo "API_MODEL_PATH: $API_MODEL_PATH"
echo "TENANT_ID: $TENANT_ID"
echo "TENANT_SUBSCRIPTION_ID: $TENANT_SUBSCRIPTION_ID"
echo "TENANT_USERNAME: $TENANT_USERNAME"
echo "AZS_SA_NAME: $AZS_SA_NAME"
echo "AZS_SA_RESOURCE_GROUP: $AZS_SA_RESOURCE_GROUP"

echo "Update the system."
sudo apt-get update -y

echo "Install AzureCLI."
echo "Update prerequiste for AzureCLI."
sudo apt-get install -y libssl-dev libffi-dev python-dev build-essential -y

echo "Install Python 3.5"
sudo apt-get install python3.5 -y

echo "Install Python PIP."
sudo apt install python-pip -y

echo "Upgrading Python PIP."
pip install --upgrade pip

echo "Install AzureCLI package."
sudo pip install --pre azure-cli --extra-index-url https://azurecliprod.blob.core.windows.net/bundled/azure-cli_bundle_0.2.10-1.tar.gz

echo 'Import the root CA certificate to python store.'
PYTHON_CERTIFI_LOCATION=$(python -c "import certifi; print(certifi.where())")
sudo cat /var/lib/waagent/Certificates.pem >> $PYTHON_CERTIFI_LOCATION

echo "Clone the ACS-Engine repo"
git clone https://github.com/msazurestackworkloads/acs-engine -b acs-engine-v093
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
    sudo apt install make -y

    echo "Build developer environment."
    sudo make devenv

    echo "Build the repository."
    sudo make all
else
    echo "We are going to use an existing ACS-Engine binary."

    echo "Open the zip file from the repo location."
    sudo mkdir bin
    sudo tar -zxvf examples/azurestack/acs-engine.tgz
    sudo mv acs-engine bin/
fi

echo "Printing help for acs-engine."
sudo ./bin/acs-engine --help

echo "Download the API model."
sudo wget $API_MODEL_PATH --no-check-certificate

echo "Installing pax for string manipulation."
sudo apt install pax -y

echo "Installing jq for JSON manipulation."
apt install jq -y

FILE_NAME=$(basename $API_MODEL_PATH)
echo "File name is: $FILE_NAME"

AZS_SA_CONTAINER_NAME=$(basename $(dirname $API_MODEL_PATH))
echo "AzureStack container name is: $AZS_SA_CONTAINER_NAME"

MASTER_DNS_PREFIX=$(jq '.properties.masterProfile.dnsPrefix' $FILE_NAME | tr -d \")
TENANT_ENDPOINT=$(jq '.properties.cloudProfile.resourceManagerEndpoint' $FILE_NAME | tr -d \")
STORAGE_ENDPOINT_SUFFIX=$(jq '.properties.cloudProfile.storageEndpointSuffix' $FILE_NAME | tr -d \")
KEYVAULT_DNS_SUFFIX=".$(jq '.properties.cloudProfile.keyVaultDNSSuffix' $FILE_NAME | tr -d \")"
GRAPH_ENDPOINT=$(jq '.properties.cloudProfile.graphEndpoint' $FILE_NAME | tr -d \")

echo "Generate the template using the API model."
sudo ./bin/acs-engine generate $FILE_NAME

echo "Accessing the generated templates."
sudo chmod 777 -R _output/
cd _output/

ENVIRONMENT_NAME=AzureStackUser
echo 'Register to the cloud.'
az cloud register \
  --name $ENVIRONMENT_NAME \
  --endpoint-resource-manager $TENANT_ENDPOINT \
  --suffix-storage-endpoint $STORAGE_ENDPOINT_SUFFIX \
  --suffix-keyvault-dns $KEYVAULT_DNS_SUFFIX \
  --endpoint-active-directory-graph-resource-id $GRAPH_ENDPOINT \
  --endpoint-vm-image-alias-doc 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/master/arm-compute/quickstart-templates/aliases.json' \
  --profile 2017-03-09-profile

az cloud set --name $ENVIRONMENT_NAME

echo 'Login to the cloud.'
az login \
  --username $TENANT_USERNAME \
  --password $TENANT_PASSWORD \
  --tenant $TENANT_ID

az account set --subscription $TENANT_SUBSCRIPTION_ID

echo 'Get connection string.'
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AZS_SA_NAME --resource-group $AZS_SA_RESOURCE_GROUP --query connectionString)
export AZURE_STORAGE_ACCOUNT=$AZS_SA_NAME

echo "AZURE_STORAGE_CONNECTION_STRING: $AZURE_STORAGE_CONNECTION_STRING"
echo "AZURE_STORAGE_ACCOUNT: $AZURE_STORAGE_ACCOUNT"

MYDIR=$PWD
echo "Current directory is: $MYDIR"

echo "Uploading templates to the storage account: $AZURE_STORAGE_ACCOUNT, Container: $AZS_SA_CONTAINER_NAME"

az storage blob upload \
  --container-name $AZS_SA_CONTAINER_NAME \
  --name "$MASTER_DNS_PREFIX/azuredeploy.json" \
  --file "$MYDIR/$MASTER_DNS_PREFIX/azuredeploy.json"

az storage blob upload \
  --container-name $AZS_SA_CONTAINER_NAME \
  --name "$MASTER_DNS_PREFIX/azuredeploy.parameters.json" \
  --file "$MYDIR/$MASTER_DNS_PREFIX/azuredeploy.parameters.json"

echo "Ending test for acsengine-generate-template."



