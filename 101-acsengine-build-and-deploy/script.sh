set -e

echo "Starting test for acsengine-build-and-deploy."
date

echo "Running as:"
whoami

sleep 20

# Script parameters #####################################################################################################################
BUILD_ACS_ENGINE=${1}
API_MODEL=${2}
#SUBSCRIPTION_ID=${3}
echo "BUILD_ACS_ENGINE: $BUILD_ACS_ENGINE"
echo "API_MODEL: $API_MODEL"

# Install Docker ########################################################################################################################
echo "Update the system."
sudo apt-get update -y

echo "Add docker repo key."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

echo "Add docker repo." 
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "Update the system again."
sudo apt-get update -y

echo "Install docker"
sudo apt-get install docker-ce -y

# Get ACS-Engine repo and build #########################################################################################################
echo "Install Make."
sudo apt install make -y

echo "checkout git project"
git clone https://github.com/msazurestackworkloads/acs-engine
cd acs-engine
git checkout -b acs-engine-v093 origin/acs-engine-v093

echo "Build developer environment."
#make devenv

echo "Build the repository."
#make all

echo "Write API model to a file."
echo $API_MODEL > examples/azurestack/azurestack1.json
echo $API_MODEL >> examples/azurestack/azurestack2.json

#echo "Generate the template using the API model."
#./bin/acs-engine generate examples/azurestack/azurestack1.json

# Deploy the template using AzureCLI ###################################################################################################


########################################################################################################################################
echo "Completed test acsengine-build-and-deploy."