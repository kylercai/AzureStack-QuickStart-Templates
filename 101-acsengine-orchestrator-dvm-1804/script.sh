set -e

echo "Starting test for acsengine-orchestrator-dvm."
date

echo "Running as:"
whoami

sleep 20

# Script parameters
BUILD_ACS_ENGINE=${1}
TENANT_ENDPOINT=${2}
TENANT_ID=${3}
TENANT_SUBSCRIPTION_ID=${4}
TENANT_USERNAME=${5}
TENANT_PASSWORD=${6}
ADMIN_USERNAME=${7}
MASTER_DNS_PREFIX=${8}
AGENT_COUNT=${9}
SPN_CLIENT_ID=${10}
SPN_CLIENT_SECRET=${11}
K8S_AZURE_CLOUDPROVIDER_VERSION=${12}
REGION_NAME=${13}
SSH_PUBLICKEY="${14} ${15} ${16}"

echo "BUILD_ACS_ENGINE: $BUILD_ACS_ENGINE"
echo "TENANT_ENDPOINT: $TENANT_ENDPOINT"
echo "TENANT_ID: $TENANT_ID"
echo "TENANT_SUBSCRIPTION_ID: $TENANT_SUBSCRIPTION_ID"
echo "TENANT_USERNAME: $TENANT_USERNAME"
echo "TENANT_PASSWORD: $TENANT_PASSWORD"
echo "ADMIN_USERNAME: $ADMIN_USERNAME"
echo "MASTER_DNS_PREFIX: $MASTER_DNS_PREFIX"
echo "AGENT_COUNT: $AGENT_COUNT"
echo "SPN_CLIENT_ID: $SPN_CLIENT_ID"
echo "SPN_CLIENT_SECRET: $SPN_CLIENT_SECRET"
echo "K8S_AZURE_CLOUDPROVIDER_VERSION: $K8S_AZURE_CLOUDPROVIDER_VERSION"
echo "REGION_NAME: $REGION_NAME"
echo "SSH_PUBLICKEY: $SSH_PUBLICKEY"

echo 'Printing the system information'
sudo uname -a

echo "Update the system."
sudo apt-get update -y

echo "Install AzureCLI."
sudo apt-get install -y libssl-dev libffi-dev python-dev build-essential -y
sudo apt-get install python3.5 -y
sudo apt-get install python-pip -y
pip install --upgrade pip
sudo pip install --pre azure-cli --extra-index-url https://azurecliprod.blob.core.windows.net/bundled/azure-cli_bundle_0.2.10-1.tar.gz
echo "Completed installing AzureCLI."

echo 'Import the root CA certificate to python store.'
PYTHON_CERTIFI_LOCATION=$(python -c "import certifi; print(certifi.where())")
sudo cat /var/lib/waagent/Certificates.pem >> $PYTHON_CERTIFI_LOCATION

echo 'Import the root CA to store.'
sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azsCertificate.crt
update-ca-certificates

echo 'Retrieve the AzureStack root CA certificate thumbprint'
THUMBPRINT=$(openssl x509 -in /var/lib/waagent/Certificates.pem -fingerprint -noout | cut -d'=' -f 2 | tr -d :)
echo 'Thumbprint for AzureStack root CA certificate:' $THUMBPRINT

echo "Installing pax for string manipulation."
sudo apt-get install pax -y

echo "Installing jq for JSON manipulation."
sudo apt-get install jq -y

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

PATTERN="https://management.$REGION_NAME."
if `echo $TENANT_ENDPOINT | grep $PATTERN 1>/dev/null 2>&1`
then
  echo "Validated that tenant endpoint: $TENANT_ENDPOINT is of correct format."
else
  echo "The tenant endpoint: $TENANT_ENDPOINT is not of correct format. Exiting!"
  exit 1
fi

EXTERNAL_FQDN=${TENANT_ENDPOINT##*$PATTERN}
SUFFIXES_STORAGE_ENDPOINT=$REGION_NAME.$EXTERNAL_FQDN
SUFFIXES_KEYVAULT_DNS=.vault.$REGION_NAME.$EXTERNAL_FQDN
FQDN_ENDPOINT_SUFFIX=cloudapp.$EXTERNAL_FQDN

ENVIRONMENT_NAME=AzureStackCloud
echo 'Register to the cloud.'
az cloud register \
  --name $ENVIRONMENT_NAME \
  --endpoint-resource-manager $TENANT_ENDPOINT \
  --suffix-storage-endpoint $SUFFIXES_STORAGE_ENDPOINT \
  --suffix-keyvault-dns $SUFFIXES_KEYVAULT_DNS \
  --endpoint-vm-image-alias-doc 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/master/arm-compute/quickstart-templates/aliases.json' \
  --profile 2017-03-09-profile

echo "Set the current cloud to be $ENVIRONMENT_NAME"
az cloud set --name $ENVIRONMENT_NAME

ENDPOINT_ACTIVE_DIRECTORY_RESOURCEID=$(az cloud show | jq '.endpoints.activeDirectoryResourceId' | tr -d \")
ENDPOINT_GALLERY=$(az cloud show | jq '.endpoints.gallery' | tr -d \")

echo 'Override the default file with the correct values in the API model.'

if [ -f "examples/azurestack/azurestack-kubernetes$K8S_AZURE_CLOUDPROVIDER_VERSION.json" ]
then
	echo "Found azurestack-kubernetes$K8S_AZURE_CLOUDPROVIDER_VERSION.json."
else
	echo "File azurestack-kubernetes$K8S_AZURE_CLOUDPROVIDER_VERSION.json does not exist. Exiting..."
	exit 1
fi

echo "Copying the default file API model to $PWD."
sudo cp examples/azurestack/azurestack-kubernetes$K8S_AZURE_CLOUDPROVIDER_VERSION.json azurestack.json
if [ -s "azurestack.json" ] ; then
	echo "Found azurestack.json in $PWD and is > 0 bytes"
else
	echo "File azurestack.json does not exist in $PWD or is zero length."
	exit 1
fi

sudo cat azurestack.json | jq --arg THUMBPRINT $THUMBPRINT '.properties.cloudProfile.resourceManagerRootCertificate = $THUMBPRINT' | \
jq --arg ENDPOINT_ACTIVE_DIRECTORY_RESOURCEID $ENDPOINT_ACTIVE_DIRECTORY_RESOURCEID '.properties.cloudProfile.serviceManagementEndpoint = $ENDPOINT_ACTIVE_DIRECTORY_RESOURCEID' | \
jq --arg TENANT_ENDPOINT $TENANT_ENDPOINT '.properties.cloudProfile.resourceManagerEndpoint = $TENANT_ENDPOINT' | \
jq --arg ENDPOINT_GALLERY $ENDPOINT_GALLERY '.properties.cloudProfile.galleryEndpoint = $ENDPOINT_GALLERY' | \
jq --arg SUFFIXES_STORAGE_ENDPOINT $SUFFIXES_STORAGE_ENDPOINT '.properties.cloudProfile.storageEndpointSuffix = $SUFFIXES_STORAGE_ENDPOINT' | \
jq --arg SUFFIXES_KEYVAULT_DNS $SUFFIXES_KEYVAULT_DNS '.properties.cloudProfile.keyVaultDNSSuffix = $SUFFIXES_KEYVAULT_DNS' | \
jq --arg FQDN_ENDPOINT_SUFFIX $FQDN_ENDPOINT_SUFFIX '.properties.cloudProfile.resourceManagerVMDNSSuffix = $FQDN_ENDPOINT_SUFFIX' | \
jq --arg REGION_NAME $REGION_NAME '.properties.cloudProfile.location = $REGION_NAME' | \
jq --arg MASTER_DNS_PREFIX $MASTER_DNS_PREFIX '.properties.masterProfile.dnsPrefix = $MASTER_DNS_PREFIX' | \
jq --arg ADMIN_USERNAME $ADMIN_USERNAME '.properties.linuxProfile.adminUsername = $ADMIN_USERNAME' | \
jq --arg SSH_PUBLICKEY "${SSH_PUBLICKEY}" '.properties.linuxProfile.ssh.publicKeys[0].keyData = $SSH_PUBLICKEY' | \
jq --arg SPN_CLIENT_ID $SPN_CLIENT_ID '.properties.servicePrincipalProfile.clientId = $SPN_CLIENT_ID' | \
jq --arg SPN_CLIENT_SECRET $SPN_CLIENT_SECRET '.properties.servicePrincipalProfile.secret = $SPN_CLIENT_SECRET' > azurestack_temp.json

if [ -s "azurestack_temp.json" ] ; then
	echo "Found azurestack_temp.json in $PWD and is > 0 bytes"
else
	echo "File azurestack_temp.json does not exist in $PWD or is zero length. Error happend during building the input API model or cluster definition."
	exit 1
fi

sudo mv azurestack_temp.json azurestack.json
echo "Done building the API model based on the stamp information."

echo 'Login to the cloud.'
az login \
  --username $TENANT_USERNAME \
  --password $TENANT_PASSWORD \
  --tenant $TENANT_ID

echo "Setting subscription to $TENANT_SUBSCRIPTION_ID"
az account set --subscription $TENANT_SUBSCRIPTION_ID

MYDIR=$PWD
echo "Current directory is: $MYDIR"

echo "Generate and Deploy the template using the API model in resource group $MASTER_DNS_PREFIX."
sudo ./bin/acs-engine deploy --resource-group $MASTER_DNS_PREFIX --azure-env $ENVIRONMENT_NAME --location $REGION_NAME --subscription-id $TENANT_SUBSCRIPTION_ID --client-id $SPN_CLIENT_ID --client-secret $SPN_CLIENT_SECRET --auth-method client_secret --api-model azurestack.json

echo "Accessing the generated templates."
sudo chmod 777 -R _output/
cd _output/

echo "Ending test for acsengine-orchestrator-dvm."



