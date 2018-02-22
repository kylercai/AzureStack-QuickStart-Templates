set -e

echo "Starting test for acsengine-build-and-deploy."
date

echo "Running as:"
whoami

sleep 20

# Script parameters #####################################################################################################################
BUILD_ACS_ENGINE=${1}
API_MODEL=${2}
echo "BUILD_ACS_ENGINE: $BUILD_ACS_ENGINE"
echo "API_MODEL: $API_MODEL"

echo "Update the system."
sudo apt-get update -y

echo "Clone the repo"
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
    make devenv

    echo "Build the repository."
    make all
else
    echo "We are going to use an exisiting ACS-Engine binary."

    echo "Open the zip file from the repo location."
    mkdir bin
    tar -zxvf examples/azurestack/acs-engine.tgz
    mv acs-engine bin/
fi

echo "Generate the template using the API model."
./bin/acs-engine --help

echo "Completed test acsengine-build-and-deploy."
