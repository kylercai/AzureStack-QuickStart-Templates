# Login to your Azure account / subscription – this will prompt you with an interactive login.
# Deploy in Azure ###################################################################################################################
# Login to your Azure account / subscription – this will prompt you with an interactive login.
Add-AzureRmAccount -EnvironmentName AzureCloud -TenantId "72f988bf-86f1-41af-91ab-2d7cd011db47" -SubscriptionId "9ee2ec52-83c0-405e-a009-6636ead37acd"

$TenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"
Select-AzureRmSubscription -SubscriptionID 9ee2ec52-83c0-405e-a009-6636ead37acd -TenantId $TenantID

Get-AzureRmADApplication -ApplicationId "7c4b28f9-526f-4ce6-9b2a-ba173dec1722"

$resourceGroupName = "radhikgu-k8s8"
$resourceGroupDeploymentName = "$($resourceGroupName)Deployment"

# Create a resource group:
New-AzureRmResourceGroup -Name $resourceGroupName -Location "West Central US"

# Deploy template to resource group: Deploy using a local template and parameter file
New-AzureRmResourceGroupDeployment  -Name $resourceGroupDeploymentName `
                                    -ResourceGroupName $resourceGroupName `
                                    -TemplateFile "E:\Documents\GitHub\AzureStack-QuickStart-Templates\101-acsengine-kubernetes\azure_azuredeploy.json" `
                                    -TemplateParameterFile "E:\Documents\GitHub\AzureStack-QuickStart-Templates\101-acsengine-kubernetes\azure_azuredeploy.parameters.json"


# Deploy in one-node Azure Stack #######################################################################################################
Get-Date
Import-Module C:\Kubernetes\AzureStack.Connect.psm1

Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint "https://management.local.azurestack.external"

$TenantID = Get-AzsDirectoryTenantId -AADTenantName "azurestackci08.onmicrosoft.com" -EnvironmentName AzureStackUser
$TenantID 
$UserName='tenantadmin1@msazurestack.onmicrosoft.com'
$Password='User@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential= New-Object PSCredential($UserName,$Password)
Login-AzureRmAccount -EnvironmentName "AzureStackUser" -TenantId $TenantID -Credential $Credential
Select-AzureRmSubscription -SubscriptionId 8bca0c44-a77e-4fe4-9955-b126ff19aa41

$resourceGroupName = "k8s-4788236"
$resourceGroupDeploymentName = "$($resourceGroupName)Deployment"
$resourceGroupOutputName = "$($resourceGroupName)-out.txt"

# Create a resource group:
New-AzureRmResourceGroup -Name $resourceGroupName -Location "local"

# Deploy template to resource group: Deploy using a local template and parameter file
$key = New-AzureRmResourceGroupDeployment  -Name $resourceGroupDeploymentName -ResourceGroupName $resourceGroupName `
                                           -TemplateFile "C:\Kubernetes\azuredeploy.json" `
                                           -TemplateParameterFile "C:\Kubernetes\azuredeploy.parameters.json" -Verbose
Write-Output $key
$key.OutputsString > $resourceGroupOutputName
Get-Date

# Deploy in multi-node Azure Stack #######################################################################################################

Import-Module C:\CloudDeployment\AzureStack.Connect.psm1

Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint "https://management.redmond.ext-u15e0303.masd.stbtest.microsoft.com"
$TenantID = Get-AzsDirectoryTenantId -AADTenantName "azurestackci13.onmicrosoft.com" -EnvironmentName AzureStackUser
$TenantID
$UserName='tenantadmin1@msazurestack.onmicrosoft.com'
$Password='User@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential= New-Object PSCredential($UserName,$Password)

Login-AzureRmAccount -EnvironmentName "AzureStackUser" -TenantId $TenantID -Credential $Credential 
Select-AzureRmSubscription -SubscriptionId 3c779415-1821-43ad-9732-dae8fa115229

$resourceGroupName = "radhikgu-k8s1d"
$resourceGroupDeploymentName = "$($resourceGroupName)Deployment"

# Create a resource group:
New-AzureRmResourceGroup -Name $resourceGroupName -Location "redmond"

# Deploy template to resource group: Deploy using a local template and parameter file
New-AzureRmResourceGroupDeployment  -Name $resourceGroupDeploymentName -ResourceGroupName $resourceGroupName `
                                    -TemplateFile "C:\Kubernetes\azuredeploy_multi.json" `
                                    -TemplateParameterFile "C:\Kubernetes\azuredeploy.parameters_multi.json" -Verbose