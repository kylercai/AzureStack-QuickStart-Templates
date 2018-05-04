echo "Installing Azure CLI"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/radhikagupta5/AzureStack-QuickStart-Templates/radhikgu-acs/101-acsengine-kubernetes-test/DeploymentTemplates/install.py"
wget $INSTALL_SCRIPT_URL
if ! command -v python >/dev/null 2>&1
then
  echo "ERROR: Python not found. 'command -v python' returned failure."
  echo "If python is available on the system, add it to PATH. For example 'sudo ln -s /usr/bin/python3 /usr/bin/python'"
  exit 1
fi
chmod 777 install.py
echo "Running install script to install Azure CLI."
python install.py
echo "Completed installing AzureCLI."