The Azure Container Service Engine (acs-engine) generates ARM (Azure Resource Manager) templates for Docker enabled clusters on Microsoft Azure with your choice of DC/OS, Kubernetes, Swarm Mode, or Swarm orchestrators.

# To learn more about generating templates using ACS-Engine refer to ACS Engine: 
https://github.com/msazurestackworkloads/acs-engine/blob/master/docs/kubernetes.md


We have modified acs-engine to work with AzureStack. 
Here are some important links:
1) Modifed ACS-Engine repo: 
	https://github.com/msazurestackworkloads/acs-engine/tree/acs-engine-v093

2) Linux binary: 
	https://github.com/msazurestackworkloads/acs-engine/tree/acs-engine-v093/examples/azurestack/acs-engine.tgz

3) Example of working JSON: 
	https://github.com/msazurestackworkloads/acs-engine/tree/acs-engine-v093/examples/azurestack/azurestack.json
 

================================================================================
STEPS: Please follow the steps below try Kubernetes: Collect stamp information for API model, generate and deploy the template.

1) Prerequistes:

	a) You need to be able to create SPN (applications) in your tenant AAD (in Azure portal) for Kubernetes deployment. 
	   Following can be used to check if you have appropriate permissions:
	   https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal#check-azure-active-directory-permissions

	b) SSH key is required to login to the Linux VMs.
	   https://github.com/msazurestackworkloads/acs-engine/blob/master/docs/ssh.md#ssh-key-generation

	c) Required modules: AzureStack (v 1.2.11), AzureRM.Resources (v 4.4.1), AzureRM.Storage (v 1.0.5.4). Most likely you already have these if you have used any AzureRm cmdlets.

	d) Ensure that following Ubuntu image is added from marketplace to PIR,
    Publisher = "Canonical"
    Offer = "UbuntuServer"
    SKU = "16.04-LTS"
    Version = "16.04.201801260"
    OSType = "Linux"

	e) You also need to download Custom Script for Linux, 2.0.3 from the marketplace.

2) Ensure that you have a valid subscription in your AzureStack tenant portal (enough public IP quota to try few applications).

   $tenantSubscriptionId = "4a4be501-4cb1-431b-a55d-b700ccfc3edd"

3) Download the following two file on your developer box (currently only avaiable for Windows) and import the module AzureStack.AcsEngine

   https://raw.githubusercontent.com/radhikagupta5/AzureStack-QuickStart-Templates/radhikgu-acs/101-acsengine-kubernetes/AzureStack.AcsEngine.psm1

   https://raw.githubusercontent.com/radhikagupta5/AzureStack-QuickStart-Templates/radhikgu-acs/101-acsengine-kubernetes/azurestack-default.json

   Import-Module E:\Data\Fundamentals\Kubernetes\AzureStack.AcsEngine.psm1 -Force

4) Call the method to prepare API model,

Highly recommend using naming suffix to keep unique DNS in shared environments.

$namingSuffix = 10000..99999 | Get-Random

$masterDnsPrefix = "k8s-" + $namingSuffix

$apiModelParameters = @{'ErcsComputerName' = "10.193.130.224";
						'CloudAdminCredential' = $cloudAdminCredential;
						'ServiceAdminCredential' = $serviceAdminCredential;
						'TenantAdminCredential' = $tenantAdminCredential;
						'TenantSubscriptionId' = $tenantSubscriptionId;
						'MasterDnsPrefix' = $masterDnsPrefix;
						'LinuxVmSshKey' = $acsSshKey;
						'NamingSuffix' = $namingSuffix;}

$apiModel = Prepare-AcseApiModel @apiModelParameters

It will upload the API model to a storage account and provide the needed information.E.g.: $apiModel

Name                           Value                                                                                                                                                                                 
----                           -----                                                                                                                                                                                 
blobRootPath                   https://k8ssa62281.blob.redmond.azurestack.corp.microsoft.com/k8ssaci62281                                                                                                            
spnApplicationId               47180043-c0ff-4f97-95aa-2b8a23b3aace                                                                                                                                                                                     
apiModelBlobPath               https://k8ssa62281.blob.redmond.azurestack.corp.microsoft.com/k8ssaci62281/azurestack.json                                                                                            
storageAccountName             k8ssa62281                                                                                                                                                                            
storageAccountResourceGroup    k8ssa-62281   

5) Ensuring that the service principal has access to the subcription.

   Assign-AcseServicePrincipal -TenantArmEndpoint $tenantArmEndpoint -AadTenantId $aadTenantId -TenantAdminCredential $tenantAdminCredential -TenantSubscriptionId $tenantSubscriptionId -ApplicationId $spnApplicationId 


6) Generate the template (You would need to SSH into a Linux VM for following steps),

	git clone https://github.com/msazurestackworkloads/acs-engine -b acs-engine-v093
	cd acs-engine
	sudo tar -zxvf examples/azurestack/acs-engine.tgz
	sudo wget <$apiModelBlobPath from output of Step 4> --no-check-certificate
	sudo ./acs-engine generate azurestack.json
	cd _output/

	This will generae a new folder containing your templates.

7) Deploy the kubernetes template using,

	"azuredeploy.parameters.json"
	"azuredeploy.json"

8) Try a few applications by installing Helm

9) If you need to deploy another deployment, modify namingSuffix and repeat all the steps.

