<#
.SYNOPSIS
Automation for HealthCare Length Of Stay (LOS) Blueprint.    

.DESCRIPTION
    The deployment script is designed to deploy the core elements of the Azure Healthcare Length of Stay solution. The details of the solutions operation, and elements can be reviewed at aka.ms/healthcareblueprint
Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

For Machine Learning module, MIT License can be found here https://raw.githubusercontent.com/hning86/azuremlps/master/LICENSE.txt

.EXAMPLE

.\deployIaaS.ps1 -installModules

This command will validate or install any missing PowerShell modules that the solution requires.

.EXAMPLE

.\deployIaaS.ps1 -deploymentPrefix <prefix>
             -tenantId <tenant-id>
             -tenantDomain <tenant-domain>
             -subscriptionId <subscription-id>
             [-globalAdminUsername <username>]
             [-deploymentPassword <password>]
This command deploys the solution and sets a single common password for all solution users, for testing purposes.

Note: For all the other switches please documentation.

.EXAMPLE

.\deployIaaS.ps1 -cleardeploymentPrefix <deployment-prefix> 
             -tenantId <tenant-id>
             -subscriptionId <subscription-id>
             -tenantDomain <tenant-domain>
             [-globalAdminUsername <username>]
             -clearDeployment
Uninstalls the solution, removing all resource groups, service principles, AD applications, and AD users.

#>

[CmdletBinding()]
param
(
    #Any 5 length prefix starting with an alphabet.
    [Parameter(Mandatory = $true, 
    ParameterSetName = "Deployment", 
    Position = 1)]
    [Alias("prefix")]
    [ValidateLength(1,5)]
    [ValidatePattern("[a-z][a-z0-9]")]
    [string]$deploymentPrefix,

    [Parameter(Mandatory = $true, 
    ParameterSetName = "CleanUp", 
    Position = 1)]
    [Alias("clearPrefix")]
    [ValidateLength(1,5)]
    [ValidatePattern("[a-z][a-z0-9]")]
    [string[]]$clearDeploymentPrefix,

    #Azure AD Tenant Id.
    [Parameter(Mandatory = $true,
    ParameterSetName = "Deployment",
    Position = 2)]
    [Parameter(Mandatory = $true, 
    ParameterSetName = "CleanUp", 
    Position = 2)]
    [guid]$tenantId,

    #Azure Subscription Id.
    [Parameter(Mandatory = $true,
    ParameterSetName = "Deployment",
    Position = 3)]
    [Parameter(Mandatory = $true, 
    ParameterSetName = "CleanUp", 
    Position = 3)]
    [Alias("subId")]
    [guid]$subscriptionId,

    #Azure Tenant Domain name.
    [Parameter(Mandatory = $true,
    ParameterSetName = "Deployment",
    Position = 4)]
    [Parameter(Mandatory = $true, 
    ParameterSetName = "CleanUp", 
    Position = 4)]
    [Alias("domain")]
    [ValidatePattern("[.]")]
    [string]$tenantDomain,

    #Subcription GlobalAdministrator Username.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 5)]
    [Parameter(Mandatory = $false, 
    ParameterSetName = "CleanUp", 
    Position = 5)]
    [Alias("userName")]
    [string]$globalAdminUsername = 'null',

    #GlobalAdministrator Password in a plain text.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 6)]
    [Parameter(Mandatory = $false, 
    ParameterSetName = "CleanUp", 
    Position = 6)]
    [Alias("password")]
    [securestring]$globalAdminPassword,

    #Location. Default is westcentralus.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 7)]
    [Parameter(Mandatory = $false, 
    ParameterSetName = "CleanUp", 
    Position = 7)]
    [ValidateSet("westus2","westcentralus", "eastus")]
    [Alias("loc")]
    [string]$location = "westcentralus",

    #[Optional] Strong deployment password. Auto-generates password if not provided.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 8)]
    [Alias("dpwd")]
    [string]$deploymentPassword = 'null',

    #Environment.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 9)]
    [Parameter(Mandatory = $false, 
    ParameterSetName = "CleanUp", 
    Position = 8)]
    [Alias("env")]
    [ValidateSet("prod","dev")] 
    [string]$environment = 'dev',

    #Switch to install required modules.
    [Parameter(Mandatory = $true,
    ParameterSetName = "InstallModules")]
    [switch]$installModules,

    #Switch to cleanup deployment resources from the subscription.
    [Parameter(Mandatory = $true, 
    ParameterSetName = "CleanUp", 
    Position = 9)]
    [switch]$clearDeployment,

    #Switch to set password policy to expire after 60 days at domain level.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 10)]
    [switch]$enableADDomainPasswordPolicy,
    
    #Switch to enable multi-factor authentication for deployed user accounts.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 11)]
    [switch]$enableMFA,

    #Select Application Insights Pricing Plan.
    [Parameter(Mandatory = $false,
    ParameterSetName = "Deployment",
    Position = 12)]
    [ValidateSet(0,1,2)]
    [Int]$appInsightsPlan = 1

)

### Manage Session Configuration
$Host.UI.RawUI.WindowTitle = "HealthCare LOS Deployment IaaS $deploymentPrefix"
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
Set-StrictMode -Version 3
$scriptRoot = Split-Path $MyInvocation.MyCommand.Path
Set-Location $scriptRoot

### Create Output folder to store logs, deployment files.
if(! (Test-Path -Path "$(Split-Path $MyInvocation.MyCommand.Path)\output")) {
    New-Item -Path $(Split-Path $MyInvocation.MyCommand.Path) -Name 'output' -ItemType Directory
}
$outputFolderPath = "$(Split-Path $MyInvocation.MyCommand.Path)\output"

### Importing custom powershell functions.
. $scriptroot\scripts\pshscripts\PshFunctions.ps1
log "Imported custom powershell modules (scripts\pshscripts\PshFunctions.ps1)."
. $scriptroot\scripts\pshscripts\PshFunctionsIaaS.ps1
log "Imported custom powershell modules (scripts\pshscripts\PshFunctionsIaaS.ps1)."

### Install required powershell modules (the current build of automation is bound to the following modules and their version number.).
$requiredModules=@{
   'AzureRM' = '4.4.0';
#    'AzureAD' = '2.0.0.131';
#    'SqlServer' = '21.0.17199';
#    'MSOnline' = '1.1.166.0'
}

if ($installModules) {
    log "Trying to install listed modules.."
    $requiredModules
    Install-RequiredModules -moduleNames $requiredModules
    log "Required modules installed. Re-run deploy.ps1 script without 'installModules'." Cyan
    Break
}

### Converting deployment prefix to lowercase
if($deploymentprefix) {
    $deploymentprefix = $deploymentprefix.ToLower()
}

log "Removing incompatible modules."
$modules = $requiredModules.Keys
foreach ($module in $modules){
    Remove-Module -Name $module -ErrorAction SilentlyContinue
}
Start-Sleep 5

log "Importing required modules."
try {
    foreach ($module in $modules){
        log "Importing - $module."
        Import-Module -Name $module -RequiredVersion $requiredModules[$module]
        if (Get-Module -Name $module) {
            log "Module - $module imported."
        }
    }
}
catch {
    logerror
    Write-Host "Current PowerShell modules are incompatible. To correct run the following command 'deploy.ps1 -installModules'." -foregroundcolor Cyan
    Break
}

log "Removing all stale credentials, account, and subscription from prior installation."
Clear-AzureRmContext -Scope CurrentUser -Force

log "Connecting to the Global Administrator Account for Subscription $subscriptionId."

if(($globalAdminUsername -ne $null) -and ($globalAdminPassword -ne $null))
{
    ### Creating the GlobalAdmin credential object
    $credential = New-Object System.Management.Automation.PSCredential ($globalAdminUsername, $globalAdminPassword)

    try {
        Login-AzureRmAccount -Credential $credential -Subscription $subscriptionId
        log "Established connection to Global Administrator Account." Green
    }
    catch {
        log "$($Error[0].Exception.Message)" Yellow
        log "Failed to connect to the Global Administrator Account. Please login manually when prompted." Cyan
        Login-AzureRmAccount -Subscription $subscriptionId
    }
} else {
    Login-AzureRmAccount -Subscription $subscriptionId
}

if ($clearDeployment) {
    try {
        log "Removing Resources." Magenta
        foreach ($countDeploymentprefix in $cleardeploymentPrefix){
        #List The Resource Group
        $resourceGroupList =@(
            ($countDeploymentprefix)
        )
        log "Resource Groups: " Cyan -displaywithouttimestamp
        $rgCount = 0
        $resourceGroupList | ForEach-Object {
            $resourceGroupName = $_
            $resourceGroupObj = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
            
            if($resourceGroupObj -ne $null)
            {
                log "$($resourceGroupObj.ResourceGroupName)." -displaywithouttimestamp -nonewline
                $rgCount = 1 
            }
            else 
            {
                log "$resourceGroupName resource group does not exist." -displaywithouttimestamp
            }
        }

        #List the Service principal
        log "Service Principals: " Cyan -displaywithouttimestamp
        $servicePrincipalObj = Get-AzureRmADServicePrincipal -SearchString $countDeploymentprefix -ErrorAction SilentlyContinue
        if ($servicePrincipalObj -ne $null)
        {
            $servicePrincipalObj | ForEach-Object {
                log "$($_.DisplayName)" -displaywithouttimestamp -nonewline
            }
        }
        else{ 
            log "Service Principal does not exist for '$countDeploymentprefix' prefix" Yellow
        }

        #List of AD Application
        $adApplicationObj = Get-AzureRmADApplication -DisplayNameStartWith "$countDeploymentprefix-SQL-ADPrincipal"
        log "AD Applications: " Cyan -displaywithouttimestamp
        if($adApplicationObj -ne $null){
            log "$($adApplicationObj.DisplayName)" -displaywithouttimestamp -nonewline
        }
        Else{
            log "AD Application does not exist for '$countDeploymentprefix' prefix" Yellow -displaywithouttimestamp
        }

        Write-Host ""
        # Remove deployment resources
        $message = "Please confirm if you want to delete the following resources."
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Deletes deployment resources"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Skips deployment resources deletion"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        #$result = $host.ui.PromptForChoice($null, $message, $options, 0)
        $result = 0 # $result value is spcifically set for CI-CD purpose. This should be removed when code is moved to Public repository.
        switch ($result){
            0 {
                # Remove ResourceGroups
                if ($rgCount -eq 1)
                {
                $resourceGroupList =@(
                    ($countDeploymentprefix)
                )
                $resourceGroupList | ForEach-Object { 
                    $resourceGroupName = $_
                        Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue | Out-Null
                        log "Deleting resource group $resourceGroupName" Yellow -displaywithouttimestamp
                        Remove-AzureRmResourceGroup -Name $resourceGroupName -Force -ErrorAction SilentlyContinue | Out-Null
                        log "ResourceGroup $resourceGroupName deleted" Yellow -displaywithouttimestamp
                    }
                }

                # Remove Service Principal
                if ($servicePrincipals = Get-AzureRmADServicePrincipal -SearchString $countDeploymentprefix) {
                    $servicePrincipals | ForEach-Object {
                        log "Removing Service Principal - $($_.DisplayName)."
                        Remove-AzureRmADServicePrincipal -ObjectId $_.Id -Force
                        log "Service Principal - $($_.DisplayName) removed" Yellow -displaywithouttimestamp
                    }
                }

                #Remove AAD Application.
                if($adApplicationObj)
                {
                    log "Removing Azure AD Application - $countDeploymentprefix'-SQL-ADPrincipal'" Yellow -displaywithouttimestamp
                    Get-AzureRmADApplication -DisplayNameStartWith "$countDeploymentprefix-SQL-ADPrincipal" | Remove-AzureRmADApplication -Force
                    log "Azure AD Application - $countDeploymentprefix-SQL-ADPrincipal deleted successfully" Yellow -displaywithouttimestamp
                }
                log "Resources cleared successfully." Magenta
            }
            1 {
                log "Skipped - resource deletion." Cyan
            }
        }
      } #multiple prefix for-loop ends here.
    }
    catch {
        logerror
        Break
    }

    log "Removing credentials, account, and subscription from prior installation."
    Clear-AzureRmContext -Scope Process -Force
}
else {
    ### Collect deployment output into Hashtable
    $outputTable = New-Object -TypeName Hashtable

    ### Set Deployment password if not already set.
    if ($deploymentPassword -eq 'null') {
        log "Deployment password not provided. Creating password for deployment."
        $guid = New-Guid
        $guid = $guid.Guid.Substring(0, 16)

        Add-Type -AssemblyName System.web
        $generated_password = [System.Web.Security.Membership]::GeneratePassword(16,4)

        $deploymentPassword = $guid + $generated_password
        Write-Host "Generated deployment password $deploymentPassword"
        $guid = $null
        $generated_password = $null
    }
    
    
    ### Several resource providers are not auto-registered. Registering Resource provider to ensure that script runs correctly.
    log "Registering resource providers."
    try {
        $resourceProviders = @(
            "Microsoft.Storage",
            "Microsoft.Compute",
            "Microsoft.Insights",
            "Microsoft.KeyVault",
            "Microsoft.Network",
            "Microsoft.Security",
            "Microsoft.OperationalInsights"
        )
        if($resourceProviders.length) {
            foreach($resourceProvider in $resourceProviders) {
                RegisterRP($resourceProvider);
            }
        }
    }
    catch {
        logerror
        Break
    }
    
    $ResourceGroupName = $deploymentPrefix

    #
    # First thing to do: enable ASC auto-provisioning policy on subscription
    #

    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    log "Checking AzureRM context for Azure security center configuration."
    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)

    log "Getting access token for Azure security center."
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
    $token = $token.AccessToken

    $Script:asc_url = 'management.azure.com'                                   # Well-known URL endpoint

    log "Creating authentication header for ASC management endpoint."
    Set-Variable -Name asc_requestHeader -Scope Script -Value @{"Authorization" = "Bearer $token"}
    Set-Variable -Name asc_subscriptionId -Scope Script -Value $currentAzureContext.Subscription.Id

    #
    # Retrieve existing autoprovision policy, and update if needed
    #

    log "Retrieving data for ASC autoProvisioningSettings..."
    $asc_uri = "https://$asc_url/subscriptions/$asc_subscriptionId/providers/microsoft.Security/AutoProvisioningSettings/default?api-version=2017-08-01-preview"
    $asc_request = Invoke-RestMethod -Uri $asc_uri -Method Get -Headers $asc_requestHeader
    
    if($asc_request.properties.autoProvision -ne "On")
    {
        $asc_request.properties.autoProvision = "On"

        log "Turning ON ASC autoProvision for subscription."
        
        $JSON = ($asc_request | ConvertTo-Json -Depth 3)

        $result = Invoke-WebRequest -Uri $asc_uri -Method Put -Headers $asc_requestHeader -Body $JSON -UseBasicParsing -ContentType "application/json"
    } else {
        log "ASC autoProvision already enabled on subscription."
    }

    #
    # query/prepare OMS workspace
    # this code does not re-use the workspace setup by the PaaS script elements.
    # hence, allow the service tier to default per the arm template.
    #

    $omsServiceTier = $null
    $workSpaceName = $deploymentPrefix + '-OmsWorkSpace'
    $workSpace = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $deploymentPrefix -Name $workSpaceName -ErrorAction SilentlyContinue
    
    if($workSpace -ne $null) {
        log "Using existing OMS workspace with CustomerId $($workSpace[0].CustomerId.Guid) Sku $($workSpace[0].Sku)"
    } else {
        log "ARM template will create new OMS workspace."
    }

    #
    # prepare AAD identity and secret for SQL keyvault access
    #

    #	
    # generate a GUID to use as the password
    #
    $guid = New-Guid
    $sqlaadPassword = $guid.Guid.ToString()

    $SQL_aadClientSecret = $sqlaadPassword

    $SQL_aadClientDisplayName = $deploymentPrefix+'-SQL-ADPrincipal'
    $SQL_aadApplication = Get-AzureRmADApplication -DisplayName $SQL_aadClientDisplayName -ErrorAction SilentlyContinue

    if($SQL_aadApplication -ne $null) {
        $SQL_aadappguid = $SQL_aadApplication.ApplicationId[0].Guid
        $SQL_aadappguidString = $SQL_aadappguid.ToString()
        log "Using existing SQL keyvault applicationId, updating credential for $SQL_aadappguidString"
        $app_cred = New-AzureRmADAppCredential -ApplicationId $SQL_aadApplication.ApplicationId[0].Guid -Password $SQL_aadClientSecret
        if($app_cred -eq $null) {
            logerror
            Break
        }
    } else {
        $identUri = 'https://' + $deploymentPrefix + '-sqlkeyvault'
        $SQL_aadApplication = New-AzureRmADApplication -DisplayName $SQL_aadClientDisplayName -Password $SQL_aadClientSecret -IdentifierUris $identUri
        $SQL_aadappguid = $SQL_aadApplication.ApplicationId[0].Guid
        $SQL_aadappguidString = $SQL_aadappguid.ToString()
        log "Using new SQL keyvault applicationId $SQL_aadappguidString"
    }

    $SQL_aadClientSecret = ConvertTo-SecureString -AsPlainText -Force $SQL_aadClientSecret

    $servicePrincipal = Get-AzureRmADServicePrincipal -ServicePrincipalName $SQL_aadappguid
    if($servicePrincipal -eq $null) {
        Start-Sleep 5
        $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $SQL_aadappguid
    }	
    # use serviceprincipal ID as the object ID for keyvault access provisioning
    $SQL_aadappServiceIdguidString = $servicePrincipal.Id.Guid.ToString()

    #
    # determine objectId corresponding to currently running account.
    # this is used for keyvault access provisioning to ensure the current user can create a key.
    #

    $currentAzureContext = Get-AzureRmContext

    $cache = $currentAzureContext.TokenCache
    $token = $cache.ReadItems() | Where-Object { $_.TenantId -eq $currentAzureContext.Tenant.TenantId -And $_.DisplayableId -eq $currentAzureContext.Account.Id }
    if($token -eq $null) {
        log "Unable to determine current user objectId information."
        logerror
        Break
    }

    $currentUserObjectId = $token[0].UniqueId

    log "Current user objectId = $($currentUserObjectId)"

    #
    # prepare random password for SQL backups.
    #

    $guid = New-Guid
    $sqlAutobackupEncryptionPassword = $guid.Guid.ToString()
    $guid = $null

    #
    # prepare repeatable storage account name.
    #

    $SQL_StorageAccountName = $ResourceGroupName+'sqlbackup'
    $HashInput = $subscriptionId.Guid.ToString() + $SQL_StorageAccountName
    $hash = (Get-StringHash -String $HashInput).SubString(0,10).ToLower()

    $SQL_StorageAccountName = $SQL_StorageAccountName + $hash


    # a naming convention coupling exists in this section between the PaaS and IaaS deployment scripts

#	note: for testing without running through a fresh PaaS deployment (deploy.ps1), one can point this to an existing deployed PaaS SQL instance
#	$SqlDbServerName = 'xxxxx-los-sql-'+$environment
#	$SqlDbServerResourceGroup = 'xxxxx-workload-'+$environment+'-rg'

    $SqlDbServerName = $ResourceGroupName+'-los-sql-'+$environment
    $SqlDbServerResourceGroup = $ResourceGroupName+'-workload-'+$environment+'-rg'

    $SqlServerAddress = $SqlDbServerName+'.database.windows.net'
    $VNetName = $ResourceGroupName+'-SQLVM-VNet'
    $SubnetName = 'SQLSubnet'
    $VMName = $ResourceGroupName+'-SQLVM'
    $AdminUserName = $ResourceGroupName+'-admin'

    #
    # derive names for credential (on SQL server), and keyname (in key vault)
    #

    $KeyVaultCredentialName = "$($resourceGroupName)SQLAKVCred"
    $KeyVaultKeyName = "$($resourceGroupName)SQLAKVKey"

    $AutoBackupPassword = ConvertTo-SecureString -AsPlainText -Force $sqlAutobackupEncryptionPassword

    #
    # create resource group
    #

    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Verbose -Force

    #
    # deploy VM
    # 

    $OptionalParameters = New-Object -TypeName Hashtable

    $OptionalParameters['vmName'] = $VMName
    $OptionalParameters['adminUserName'] = $AdminUserName    
    $OptionalParameters['adminPassword'] = ConvertTo-SecureString -AsPlainText -Force $deploymentPassword
    $OptionalParameters['sqlaadApplicationServiceId'] = $SQL_aadappServiceIdguidString
    $OptionalParameters['sqlaadApplicationId'] = $SQL_aadappguidString
    $OptionalParameters['sqlaadClientSecret'] = $SQL_aadClientSecret
    $OptionalParameters['sqlAutobackupEncryptionPassword'] = ConvertTo-SecureString -AsPlainText -Force $sqlAutobackupEncryptionPassword
    $OptionalParameters['sqlBackupStorageAccountName'] = $SQL_StorageAccountName
    $OptionalParameters['currentUserObjectId'] = $currentUserObjectId
    $OptionalParameters['omsWorkSpaceName'] = $workSpaceName
    if($omsServiceTier -ne $null) {
        $OptionalParameters['omsServiceTier'] = $omsServiceTier
    }

    $TemplateFile = '.\templates\WindowsSQLVirtualMachine.json'
    $TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))

    # Create or update the resource group using the specified template file and template parameters file
    New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $TemplateFile `
                                       @OptionalParameters `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages

    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    } else {

        Write-Host '***VM username=' $AdminUserName
        Write-Host '***VM admin Password=' $deploymentPassword ' will be reset to random after next step.' 
        Write-Host '***SQL backup encryption Password=' $sqlAutobackupEncryptionPassword

        #
        # at this point, the VM is up and running.
        # update the network security group and access policy, transfer and execute payload.
        #


        #
        # update PaaS firewall and access policy
        #

        $status = Update-SqlIaaSExtensionKeyVault -resourceGroupName $ResourceGroupName `
                    -VMName $VMName -autoBackupPassword $AutoBackupPassword `
                    -KeyVaultServicePrincipalName $SQL_aadappguidString -KeyVaultServicePrincipalSecret $SQL_aadClientSecret `
                    -KeyVaultCredentialName $KeyVaultCredentialName -KeyVaultKeyName $KeyVaultKeyName

        if($status -ne $true)
        {
            echo "Error updating SqlIaaSExtension keyvault integration."
            logerror
            Break
        }

        $status = Update-AccessPolicySqlFunction -resourceGroupName $ResourceGroupName -environment $environment `
                -SqlDbServerName $SqlDbServerName -SqlDbServerResourceGroup $SqlDbServerResourceGroup `
                -VNetName $VNetName -VMName $VMName

        if($status -ne $true)
        {
            echo "PaaS SQL instance firewall and network security group configuration update failed!"
            logerror
            Break
        }

        #
        # prepare artifacts for transfer and execution.
        #

        $UniqueStorageSuffix = ( ([char[]]([char]97..[char]122)) + 0..9 | sort {Get-Random})[0..20] -join ''
        $ArtifactsStorageAccountName = $ResourceGroupName+'stg' + $uniqueStorageSuffix
        $ArtifactsStorageAccountName = $ArtifactsStorageAccountName.Substring(0, 23)
        $ArtifactsStorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts'

        $resultArray = TransferExecute-PayloadFunction -resourceGroupName $ResourceGroupName `
                        -artifactsStorageAccountName $ArtifactsStorageAccountName -artifactsStorageContainerName $ArtifactsStorageContainerName `
                        -VNetName $VNetName

        $ArtifactsStorageAccount = $resultArray[0]

        # read-only SAS token valid for 1 hour
        $ArtifactsStorageKey = ConvertTo-SecureString -AsPlainText -Force `
            (New-AzureStorageContainerSASToken -Container $ArtifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(1))

        $OptionalParametersPayload = New-Object -TypeName Hashtable

        $OptionalParametersPayload['_artifactsLocation'] = $ArtifactsStorageAccount.Context.BlobEndPoint + $ArtifactsStorageContainerName
        $OptionalParametersPayload['_artifactsStorageKey'] =  $ArtifactsStorageKey
        $OptionalParametersPayload['sqlServerAddress'] =  $SqlServerAddress
        $OptionalParametersPayload['adminUserName'] = $AdminUserName
        $OptionalParametersPayload['vmName'] = $VMName
        $OptionalParametersPayload['sqlCredentialName'] = $KeyVaultCredentialName
        $OptionalParametersPayload['sqlKeyVaultKeyName'] = $KeyVaultKeyName


        $TemplateFile = '.\templates\WindowsSQLVirtualMachinePayload.json'
        $TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))

        New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                            -ResourceGroupName $ResourceGroupName `
                                            -TemplateFile $TemplateFile `
                                            @OptionalParametersPayload `
                                            -Force -Verbose `
                                            -ErrorVariable ErrorMessagesPayload

        if ($ErrorMessagesPayload) {
            Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessagesPayload) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
        }

        #
        # unconditionally delete the artifacts storage account.
        #

        log "Removing artifacts storage account $($ArtifactsStorageAccountName)."
        Remove-AzureRmStorageAccount -ResourceGroup $ResourceGroupName -Name $ArtifactsStorageAccountName -Force

        #
        # complete, output VM username and password info (do NOT log passwords to file)
        #

        log "***VM username= $($AdminUserName)"
        log "***VM admin Password, reset to random value, use management portal to reset password if necessary"
        Write-Host '***SQL backup encryption Password=' $sqlAutobackupEncryptionPassword
    }
    
    log "Finalising deployment and generating output json - $($deploymentPrefix)-deploymentOutput.json."

    ## Store deployment output to CloudDrive folder else to Output folder.
    if (Test-Path -Path "$HOME\CloudDrive") {
        log "CloudDrive was found. Saving $($deploymentPrefix)-deploymentOutput.json and $logFileName to CloudDrive.."
        $outputTable | ConvertTo-Json | Out-File -FilePath "$HOME\CloudDrive\$($deploymentPrefix)-deploymentOutputIaaS.json"
        Get-ChildItem $outputFolderPath -File -Filter *.txt | Copy-Item -Destination  "$HOME\CloudDrive\"
        log "Output file has been generated - $HOME\CloudDrive\$($deploymentPrefix)-deploymentOutputIaaS.json." Green
        #Get-Content "$HOME\CloudDrive\$($deploymentPrefix)-deploymentOutput.json"
        $outputTable.GetEnumerator() | Sort-Object -Property Name | Format-Table -AutoSize -Wrap
    }
    Else {
        log "CloudDrive was not found. Saving deploymentOutput.json to Output folder.."
        $outputTable | ConvertTo-Json | Out-File -FilePath "$outputFolderPath\$($deploymentPrefix)-deploymentOutputIaaS.json"
        log "Output file has been generated - $outputFolderPath\$($deploymentPrefix)-deploymentOutputIaaS.json." Green
        #Get-Content "$outputFolderPath\$($deploymentPrefix)-deploymentOutputIaaS.json"
        $outputTable.GetEnumerator() | Sort-Object -Property Name | Format-Table -AutoSize -Wrap
    }

    log "Removing credentials, account, and subscription context."
    Clear-AzureRmContext -Scope CurrentUser -Force
}

#### END OF SCRIPT ###