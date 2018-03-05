The Azure Container Service Engine (acs-engine) generates ARM (Azure Resource Manager) templates for Docker enabled clusters on Microsoft Azure with your choice of DC/OS, Kubernetes, Swarm Mode, or Swarm orchestrators.

# For more details refer to ACS Engine: 

https://github.com/msazurestackworkloads/acs-engine/blob/master/docs/kubernetes.md

We have modified acs-engine to work with AzureStack. Here are some important links:
Modifed ACS-Engine repo: https://github.com/msazurestackworkloads/acs-engine/tree/acs-engine-v093
Linux binary: https://github.com/msazurestackworkloads/acs-engine/tree/acs-engine-v093/examples/azurestack/acs-engine.tgz
Example of working JSON: https://github.com/msazurestackworkloads/acs-engine/tree/acs-engine-v093/examples/azurestack/azurestack.json
 
Please follow the steps below to generate and deploy a template.

1) Prerequistes:
	a) You need to be admin in your tenant AAD to be able to create SPN (application) for Kubernetes deployment.
	https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal#check-azure-active-directory-permissions

	b) SSH key.

	c) Required modules: AzureStack (v 1.2.11), AzureRM.Resources (v 4.4.1), AzureRM.Storage (v 1.0.5.4)

2) Ensure that you have a subscription in your AzureStack enviroment.
$tenantSubscriptionId = "4a4be501-4cb1-431b-a55d-b700ccfc3edd"

3) Download the following PowerShell module to your developer box (currently only avaiable for Windows) and import the module.
"https://raw.githubusercontent.com/radhikagupta5/AzureStack-QuickStart-Templates/radhikgu-acs/101-acsengine-kubernetes/AzureStack.AcsEngine.psm1"
"https://raw.githubusercontent.com/radhikagupta5/AzureStack-QuickStart-Templates/radhikgu-acs/101-acsengine-kubernetes/azurestack-default.json"

Import-Module E:\Data\Fundamentals\Kubernetes\AzureStack.AcsEngine.psm1 -Force

4) Call the method to prepare API model,

$namingSuffix = 10000..99999 | Get-Random
$masterDnsPrefix = "k8s-" + $namingSuffix

$apiModelParameters = @{'ErcsComputerName' = "10.193.130.224"
						'CloudAdminCredential' = $cloudAdminCredential
						'ServiceAdminCredential' = $serviceAdminCredential
						'TenantAdminCredential' = $tenantAdminCredential;
						'TenantSubscriptionId' = $tenantSubscriptionId;
						'MasterDnsPrefix' = $masterDnsPrefix;
						'LinuxVmSshKey' = $acsSshKey;
						'NamingSuffix' = $namingSuffix;}

$apiModel = Prepare-AcseApiModel @apiModelParameters

This will upload the API model to a storage account and provide the needed information.
E.g.:

$apiModel

Name                           Value                                                                                                                                                                                 
----                           -----                                                                                                                                                                                 
blobRootPath                   https://k8ssa62281.blob.redmond.azurestack.corp.microsoft.com/k8ssaci62281                                                                                                            
spnApplicationId                                                                                                                                                                                                     
apiModelBlobPath               https://k8ssa62281.blob.redmond.azurestack.corp.microsoft.com/k8ssaci62281/azurestack.json                                                                                            
storageAccountName             k8ssa62281                                                                                                                                                                            
storageAccountResourceGroup    k8ssa-62281   

5) 