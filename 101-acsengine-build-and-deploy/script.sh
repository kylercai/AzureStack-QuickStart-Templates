set -e

echo "Starting test for 101-acsengine-build-and-deploy."
date

echo "Running as:"
whoami

sleep 20

# Script parameters #####################################################################################################################
API_MODEL=${1}
#SUBSCRIPTION_ID=${2}

# Get ACS-Engine repo and build #########################################################################################################
echo "Update the system."
sudo apt-get update -y

echo "Install Make."
sudo apt install make -y

echo "Clone existing repository into a new directory."
git clone https://github.com/msazurestackworkloads/acs-engine -b acs-engine-v093

echo "Change directory and pull latest code."
cd acs-engine
git pull 

echo "Install docker."
sudo apt install docker.io -y

echo "Build developer environment."
make devenv

echo "Build the repository."
make all

echo "Write API model to a file."
echo $API_MODEL > examples/azurestack/azurestack1.json
echo $API_MODEL >> examples/azurestack/azurestack2.json

echo "Generate the template using the API model."
./bin/acs-engine generate examples/azurestack/azurestack1.json

# Deploy the template using AzureCLI ###################################################################################################


########################################################################################################################################
echo "Completed test 101-acsengine-build-and-deploy."