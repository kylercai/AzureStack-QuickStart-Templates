set -e

echo "Starting test for 101-acsengine-build-and-deploy."
date

echo "Running as:"
whoami

sleep 20

echo "Update the system."
sudo apt-get update -y

# Installing AzureCLI #################################################################################################################
echo "Update prerequiste for AzureCLI."
sudo apt-get install -y libssl-dev libffi-dev python-dev build-essential -y

echo "Install Python 3.5"
sudo apt-get install python3.5 -y

echo "Install Python PIP."
sudo apt install python-pip -y

echo "Upgrading Python PIP."
pip install --upgrade pip

echo "Install AzureCLI."
sudo pip install --pre azure-cli --extra-index-url https://azurecliprod.blob.core.windows.net/bundled/azure-cli_bundle_0.2.10-1.tar.gz

# Run simple command to test availablity AzureCLI
echo "Running: az --version"
az --version
########################################################################################################################################



echo "Completed test 101-acsengine-build-and-deploy."