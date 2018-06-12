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

.\deploy.ps1 -installModules

This command will validate or install any missing PowerShell modules that the solution requires.

.EXAMPLE

.\deploy.ps1 -deploymentPrefix <prefix>
             -tenantId <tenant-id>
             -tenantDomain <tenant-domain>
             -subscriptionId <subscription-id>
             -globalAdminUsername <username>
             -deploymentPassword <password>
This command deploys the solution and sets a single common password for all solution users, for testing purposes.

Note: For all the other switches please documentation.

.EXAMPLE

.\deploy.ps1 -deploymentPrefix <deployment-prefix> 
             -tenantId <tenant-id>
             -subscriptionId <subscription-id>
             -tenantDomain <tenant-domain>
             -globalAdminUsername <username>
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
    [Parameter(Mandatory = $true,
    ParameterSetName = "Deployment",
    Position = 5)]
    [Parameter(Mandatory = $true, 
    ParameterSetName = "CleanUp", 
    Position = 5)]
	[Alias("userName")]
    [string]$globalAdminUsername,

    # Global administrator password in secure string.
    [Parameter(Mandatory = $true,
    ParameterSetName = "Deployment",
    Position = 6)]
    [Parameter(Mandatory = $true, 
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
    [ValidateSet("westus2","westcentralus")]
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
$Host.UI.RawUI.WindowTitle = "HealthCare LOS Deployment"
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

# Configure transcript
Write-Host "Initiating transcript to log session."
Start-Transcript -OutputDirectory $outputFolderPath -Force

### Importing custom powershell functions.
. $scriptroot\scripts\pshscripts\PshFunctions.ps1
log "Imported custom powershell modules (scripts\pshscripts\PshFunctions.ps1)."

### Install required powershell modules (the current build of automation is bound to the following modules and their version number.).
$requiredModules=@{
    'AzureRM' = '4.4.0';
    'AzureAD' = '2.0.0.131';
    'SqlServer' = '21.0.17199';
    'MSOnline' = '1.1.166.0'
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

### Deployment actors are users defined in Blueprint scnario documentation. 
$actors = @('Alex_SiteAdmin','Danny_DBAnalyst','Caroline_ChiefMedicalInformationOfficer','Chris_CareLineManager','Han_Auditor','Debra_DataScientist')

### Creating the GlobalAdmin credential object
$credential = New-Object System.Management.Automation.PSCredential ($globalAdminUsername, $globalAdminPassword)

log "Connecting to the Global Administrator Account for Subscription $subscriptionId."
try {
    Login-AzureRmAccount -Credential $credential -Subscription $subscriptionId
    log "Established connection to Global Administrator Account." Green
    $manualLogin = 0
}
catch {
    log "$($Error[0].Exception.Message)" Yellow
    log "Failed to connect to the Global Administrator Account. Please login manually when prompted." Cyan
    Login-AzureRmAccount -Subscription $subscriptionId
    $manualLogin = 1    
}

if ($clearDeployment) {
    try {
        log "Removing Resources." Magenta
        foreach ($countDeploymentprefix in $cleardeploymentPrefix){
        #List The Resource Group
        $resourceGroupList =@(
            (($countDeploymentprefix, 'monitoring', $environment, 'rg') -join '-'),
            (($countDeploymentprefix, 'workload', $environment, 'rg') -join '-')
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
        $adApplicationObj = Get-AzureRmADApplication -DisplayNameStartWith "$countDeploymentprefix Azure HealthCare LOS Sample"
        log "AD Applications: " Cyan -displaywithouttimestamp
        if($adApplicationObj -ne $null){
            log "$($adApplicationObj.DisplayName)" -displaywithouttimestamp -nonewline
        }
        Else{
            log "AD Application does not exist for '$countDeploymentprefix' prefix" Yellow -displaywithouttimestamp
        }

        #List the AD Users
        log "AD Users: " Cyan -displaywithouttimestamp
        foreach ($actor in $actors) {
            $upn = Get-AzureRmADUser -SearchString $actor
            $fullUpn = $actor + '@' + $tenantDomain
            if ($upn -ne $null )
            {
                log "$fullUpn" -displaywithouttimestamp -nonewline
            }
        }
        if ($upn -eq $null)
        {
            log "No users found" Yellow -displaywithouttimestamp
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
                    (($countDeploymentprefix, 'monitoring', $environment, 'rg') -join '-'),
                    (($countDeploymentprefix, 'workload', $environment, 'rg') -join '-')
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

                # Remove Azure AD Users
                
                if ($upn -ne $null)
                {
                    # Prompt to remove AAD Users
                    $message = "Do you want to remove listed users?"
                    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                    "Remove users"
                    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                    "Skipping user removal"
                    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                    #$result = $host.ui.PromptForChoice($null, $message, $options, 0)
                    $result = 0 # $result value is spcifically set for CI-CD purpose. This should be removed when code is moved to Public repository.
                    switch ($result){
                        0 {
                            log "Removing users" Yellow -displaywithouttimestamp
                            foreach ($actor in $actors) {
                                try {
                                    $upn = $actor + '@' + $tenantDomain
                                    Get-AzureRmADUser -SearchString $upn
                                    Remove-AzureRmADUser -UPNOrObjectId $upn -Force -ErrorAction SilentlyContinue
                                    log "$upn was deleted successfully. " Yellow -displaywithouttimestamp
                                }
                                catch [System.Exception] {
                                    logerror
                                    Break
                                }
                            }
                        }
                        1 {
                            log "Skipped - users removal." Cyan
                        }
                    }
                }
				
                #Remove AAD Application.
                if($adApplicationObj)
                {
                    log "Removing Azure AD Application - $countDeploymentprefix Azure HealthCare LOS Sample." Yellow -displaywithouttimestamp
                    Get-AzureRmADApplication -DisplayNameStartWith "$countDeploymentprefix Azure HealthCare LOS Sample" | Remove-AzureRmADApplication -Force
                    log "Azure AD Application - $countDeploymentprefix Azure HealthCare LOS Sample deleted successfully" Yellow -displaywithouttimestamp
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
}
else {
    ### Collect deployment output into Hashtable
    $outputTable = New-Object -TypeName Hashtable

    ### Set Deployment password if not already set.
    if ($deploymentPassword -eq 'null') {
        log "Deployment password not provided. Creating password for deployment."
        $deploymentPassword = New-RandomPassword
        log "Deployment password $deploymentPassword generated."
    }

	### Convert deploymentPasssword to SecureString.
    $secureDeploymentPassword = ConvertTo-SecureString $deploymentPassword -AsPlainText -Force

    ### Convert Service Administrator to plaintext
    $convertedServiceAdminPassword = $globalAdminPassword | ConvertFrom-SecureString 
    $securePassword = ConvertTo-SecureString $convertedServiceAdminPassword
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $plainServiceAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    ### Configure AAD User Accounts.
    log "Creating user accounts."
    try
    {
        log "Initialising powershell session to create user accounts. NOTE: Configure-AADUsers.ps1 will open a powershell window that you must close when completed."
        # In order to avoid AD connect clobbering AzureRM session, a new powershell session is required.
        if($manualLogin){
            Start-Process Powershell -ArgumentList "-NoExit", "-WindowStyle Normal", "-ExecutionPolicy UnRestricted", ".\Configure-AADUsers.ps1 -tenantId $tenantId -subscriptionId $subscriptionId -tenantDomain $tenantDomain -deploymentPassword '$deploymentPassword'" -WorkingDirectory "$scriptRoot\scripts\pshscripts"
        }
        else {
            Start-Process Powershell -ArgumentList "-NoExit", "-WindowStyle Normal", "-ExecutionPolicy UnRestricted", ".\Configure-AADUsers.ps1 -tenantId $tenantId -subscriptionId $subscriptionId -tenantDomain $tenantDomain -globalAdminUsername $globalAdminUsername -globalAdminPassword $plainServiceAdminPassword -deploymentPassword '$deploymentPassword'" -WorkingDirectory "$scriptRoot\scripts\pshscripts"            
        }
    }
    catch [System.Exception]
    {
        logerror
        Break
    }

    if ($manualLogin) {
        log "Provisioning users. Launching Configure-AADUsers.ps1." Cyan
        Write-Host "`nPress 'Enter' once user provisioning is complete on another session." -ForegroundColor Green
        Read-Host
    }
    else {
        log "Provisioning users. Launching Configure-AADUsers.ps1, waiting 40 seconds for provisioning to complete." Cyan
        Start-Sleep -Seconds 40
    }

    ### Several resource providers are not auto-registered. Registering Resource provider to ensure that script runs correctly.
    log "Registering resource providers."
    try {
        $resourceProviders = @(
            "Microsoft.Storage",
            "Microsoft.Compute",
            "Microsoft.KeyVault",
            "Microsoft.Network",
            "Microsoft.Web",
            "Microsoft.Sql",
            "Microsoft.EventGrid",
            "Microsoft.insights",
            "Microsoft.Security"
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

    ### Create resource group for the deployment and assigning RBAC to users.
    $components = @("workload", "monitoring")
    $components | ForEach-Object { 
        $rgName = (($deploymentPrefix,$_,$environment,'rg') -join '-')
        log "Creating resource group $rgName at $location."
        New-AzureRmResourceGroup -Name $rgName -Location $location -Force -OutVariable $_
    }

    ### Assign roles to the users from scripts\jsonscripts\subscription.roleassignments.json
    log "Assigning roles to the users."
    $rbactmp = [System.IO.Path]::GetTempFileName()
    $rbacData = Get-Content "$scriptroot\scripts\jsonscripts\subscription.roleassignments.json" | ConvertFrom-Json
    $rbacData.Subscription.Id = $subscriptionId
    # Removing all apostraphe u+0027 from json file with "'".
    ( $rbacData | ConvertTo-Json -Depth 10 ) -replace "\\u0027", "'" | Out-File $rbactmp
    Update-RoleAssignments -inputFile $rbactmp -prefix $deploymentPrefix -env $environment -domain $tenantDomain
    Start-Sleep 10

    ### Create PSCredential Object for SiteAdmin
    $siteAdminUserName = "Alex_SiteAdmin@" + $tenantDomain
    $siteAdmincredential = New-Object System.Management.Automation.PSCredential ($siteAdminUserName, $secureDeploymentPassword)

    ### Connect to AzureRM using SiteAdmin
    log "Connecting to subscription $subscriptionId using Alex_SiteAdmin Account."
    try {
        Login-AzureRmAccount -SubscriptionId $subscriptionId -TenantId $tenantId -Credential $siteAdmincredential
    }
    catch {
        log "$($Error[0].Exception.Message)" Yellow
        log "Failed to connect to Alex_SiteAdmin Account. Please login manually when prompted." Cyan
        Write-Host "`nUse deployment password - $deploymentPassword to login using $siteAdminUserName Account." -ForegroundColor Green
        Login-AzureRmAccount        
    }
    Start-Sleep 5

    ########### Create Azure Active Directory apps, setting up application key in AAD ###########
    try {
        # Create Active Directory Application
        $healthCareAppServiceURL = (("http://",$deploymentPrefix,"HealthCarelossamplesapplication.com") -join '' )
        $displayName = "$deploymentPrefix Azure HealthCare LOS Sample"
        if (!($healthCareAADApplication = Get-AzureRmADApplication -IdentifierUri $healthCareAppServiceURL)) {
        log "Creating AAD Application for Healthcare deployment"
        $healthCareAADApplication = New-AzureRmADApplication -DisplayName $displayName -HomePage $healthCareAppServiceURL -IdentifierUris $healthCareAppServiceURL -Password $deploymentPassword
        $healthCareAdApplicationClientId = $healthCareAADApplication.ApplicationId.Guid
        $healthCareAdApplicationObjectId = $healthCareAADApplication.ObjectId.Guid.ToString()
        log "AAD Application creation was successful. AppID is $healthCareAdApplicationClientId"
        # Create a service principal for the AD Application and add a Reader role to the principal 
        log "Creating Service principal for Healthcare deployment"
        $healthCareServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $healthCareAdApplicationClientId
        Start-Sleep -s 30 # Wait for the ServicePrincipal to complete, This may take upto 20 secs. Role assignment need to be fully deployed in the servicePrincipal
        log "Service principal created - $($healthCareServicePrincipal.DisplayName)"
        $healthCareAdServicePrincipalObjectId = (Get-AzureRmADServicePrincipal | ?  DispLayName -eq "$deploymentPrefix Azure HealthCare LOS Sample").Id.Guid
        }
        else {
            $healthCareAdApplicationClientId = $healthCareAADApplication.ApplicationId.Guid
            $healthCareAdApplicationObjectId = $healthCareAADApplication.ObjectId.Guid.ToString()
            $healthCareAdServicePrincipalObjectId = (Get-AzureRmADServicePrincipal | ?  DispLayName -eq "$deploymentPrefix Azure HealthCare LOS Sample").Id.Guid
            log "AAD Application for HealthCare-LOS already exist with AppID - $healthCareAdApplicationClientId"
            New-AzureRmADAppCredential -ObjectId $healthCareAADApplication.ObjectId.Guid -Password $deploymentPassword
        }

        #Connecting to Azure Active Directory Services.
        try {
            Connect-AzureAD -TenantId $tenantId -Credential $siteAdmincredential
        }
        catch {
            log "$($Error[0].Exception.Message)" Yellow
            log "Failed to establish session to Azure AD. Please login manually when prompted." Cyan
            Write-Host "`nUse deployment password - $deploymentPassword to login using $siteAdminUserName Account." -ForegroundColor Green
            Connect-AzureAD -TenantId $tenantId
        }

        $replyUrl =  ('https://', $deploymentPrefix ,'-admission-discharge-fapp-', $environment ,'.azurewebsites.net/.auth/login/done') -join ''
        $ServicePrincipalId = (Get-AzureADServicePrincipal -SearchString $displayName).ObjectId.ToString()
        if ($ServicePrincipalId) {
            log "ServicePrincipal $displayName found."
			log "Adding reply url $replyUrl"
			Set-AzureADApplication -ObjectId $healthCareAdApplicationObjectId -ReplyUrls $replyUrl
            if (Get-AzureADServiceAppRoleAssignment -ObjectId $ServicePrincipalId) {
                if ((Get-AzureADServiceAppRoleAssignment -ObjectId $ServicePrincipalId).PrincipalDisplayName -contains 'Chris_CareLineManager') {
                    log "AAD ServiceApp Role Assignment Chris_CareLineManager exists."
                }
                else {
                    log "Updating ReplyUrl and AppRoles on $displayName."
                    # Update Azure AD Application with Response URLs and App Roles.
                    $manifest = Get-Content "$scriptroot\scripts\jsonscripts\aad.manifest.json" | ConvertFrom-Json
                    $requiredResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
                    # Assigning scope and role using Microsoft object guids.
                    $resourceAccess1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"
                    $resourceAccess2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "5778995a-e1bf-45b8-affa-663a9f3f4d04","Role"
                    $requiredResourceAccess.ResourceAccess = $resourceAccess1,$resourceAccess2
                    $requiredResourceAccess.ResourceAppId = "00000002-0000-0000-c000-000000000000" #Resource App ID for Azure ActiveDirectory
                    Set-AzureADApplication -ObjectId $healthCareAdApplicationObjectId -AppRoles $manifest.appRoles -RequiredResourceAccess $requiredResourceAccess
        
                    # Get the user and service principal for the app role assignment.
                    $app_role_name = "Care Line Manager"
                    $user = Get-AzureADUser -SearchString 'Chris_CareLineManager'
                    $sp = Get-AzureADServicePrincipal -Filter "displayName eq '$displayName'"
                    $appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }
    
                    #Assign the user to the app role
                    log "Assigning AppRoles to Chris_CareLineManager on $displayName."
                    New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $sp.ObjectId -Id $appRole.Id
                }
            }
            else {
                log "Updating ReplyUrl and AppRoles on $displayName."
                # Update Azure AD Application with Response URLs and App Roles.
                $manifest = Get-Content "$scriptroot\scripts\jsonscripts\aad.manifest.json" | ConvertFrom-Json
                $requiredResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
                $resourceAccess1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"
                $resourceAccess2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "5778995a-e1bf-45b8-affa-663a9f3f4d04","Role"
                $requiredResourceAccess.ResourceAccess = $resourceAccess1,$resourceAccess2
                $requiredResourceAccess.ResourceAppId = "00000002-0000-0000-c000-000000000000"
                Set-AzureADApplication -ObjectId $healthCareAdApplicationObjectId -AppRoles $manifest.appRoles -ReplyUrls $replyUrl `
                    -RequiredResourceAccess $requiredResourceAccess
    
                # Get the user and service principal for the app role assignment.
                $app_role_name = "Care Line Manager"
                $user = Get-AzureADUser -SearchString 'Chris_CareLineManager'
                $sp = Get-AzureADServicePrincipal -Filter "displayName eq '$displayName'"
                $appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }

                #Assign the user to the app role
                log "Assigning AppRoles to Chris_CareLineManager on $displayName."
                New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $sp.ObjectId -Id $appRole.Id
            }
        }
        else {
            log "Error: Could not find ServicePrincipal with DisplayName - $displayName most likely the user was removed. This can be corrected by re-running deploy.ps1" Red
            Break
        }
    }
    catch {
        logerror
        log $_.Exception.Message Red
        Break
    }

    log "Collect AD details for granting access to Azure Resources."
    ### Get SiteAdmin ObjectId to grant access on KeyVault.
    log "Alex_SiteAdmin ObjectId to grant access on KeyVault"
    $siteAdminObj = Get-AzureRmADUser -SearchString 'Alex_SiteAdmin'
    $siteAdminObjId = $siteAdminObj.Id.Guid # Variable used by pshfunction.ps1

    ### Get Danny_DBAnalyst ObjectId to grant access on Sql Server.
    log "Danny_DBAnalyst ObjectId to grant access on Sql Server"
    $sqlAdAdminObj = Get-AzureRmADUser -SearchString 'Danny_DBAnalyst'
    $sqlAdAdminObjID = $sqlAdAdminObj.Id.Guid # Variable used by pshfunction.ps1

    ### Invoke ARM deployment.
    log "Intiating HealthCare-LOS Solution Deployment." Cyan

    log "Initialising powershell background job deployment for Monitoring Solution - OMS Workspace and Application Insights."
    Invoke-ARMDeployment -subscriptionId $subscriptionId -resourceGroupPrefix $deploymentPrefix -location $location -env $environment -steps 1 -prerequisiteRefresh

    # Pause Session for Background Job to Initiate.
    log "Waiting 20 seconds for background job to initiate"
    Start-Sleep 20

    #Get deployment status
    while ((Get-Job -Name '1-create' | Select-Object -Last 1).State -eq 'Running') {
        Get-ARMDeploymentStatus -jobName '1-create'
        Start-Sleep 10
    }
    if ((Get-Job -Name '1-create' | Select-Object -Last 1).State -eq 'Completed') 
    {
        Get-ARMDeploymentStatus -jobName '1-create'
    }
    else
    {
        Get-ARMDeploymentStatus -jobName '1-create'
        log $error[0] -color Red
        log "Template deployment has failed. Go to Azure Portal / Subscription --> ResourceGroup <with prefix $deploymentPrefix> --> ResourceGroup Settings --> Deployments to troubleshoot the issue."
        Break
    }

    log "Initialising powershell background job deployment for Workload deployment."
    Invoke-ARMDeployment -subscriptionId $subscriptionId -resourceGroupPrefix $deploymentPrefix -location $location -env $environment -steps 2

    # Pause Session for Background Job to Initiate.
    log "Waiting 20 seconds for background job to initiate"
    Start-Sleep 20

    #Get deployment status
    while ((Get-Job -Name '2-create' | Select-Object -Last 1).State -eq 'Running') {
        Get-ARMDeploymentStatus -jobName '2-create'
        Start-Sleep 5
    }

    if ((Get-Job -Name '2-create' | Select-Object -Last 1).State -eq 'Completed') 
    {
        Get-ARMDeploymentStatus -jobName '2-create'
        Start-Sleep 10
		$webAppName = "-learn-fapp-dev"
		$webAppName = $deploymentPrefix + $webAppName
		log "Waiting 60 seconds for restarting function app"
		Get-AzureRmWebApp -ResourceGroupName $newDeploymentResourceGroupName $webAppName | Restart-AzureRmWebApp 
		Start-Sleep 60
        log "Collect Workload deployment Output."
        $workloadDeploymentOutput = Get-AzureRmResourceGroupDeployment -ResourceGroupName $newDeploymentResourceGroupName -Name $newDeploymentName
    }
    else
    {
        Get-ARMDeploymentStatus -jobName '2-create'
        log $error[0] -color Red
        log "Template deployment has failed. Go to Azure Portal / Subscription --> ResourceGroup <with prefix $deploymentPrefix> --> ResourceGroup Settings --> Deployments to troubleshoot the issue."
        Break
    }

    # The following was used to create a single output file but deploy.ps1 was revised to next code block.
    if($workloadDeploymentOutput.OutputsString -eq $null){
        log "Critical failure occur in deploy.ps1. This can be corrected by re-running deploy.ps1" -color Red
        Break
    }
    else {
        $workloadOutputArray = ($workloadDeploymentOutput.OutputsString.Split()).Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
    }
    # Parsing deployment output.
    if($workloadDeploymentOutput -eq $null){
        log "Critical failure occur in deploy.ps1. This can be corrected by re-running deploy.ps1" -color Red
        Break
    }
    else {
        $i = 0
        if($workloadDeploymentOutput -is [system.array]){$count = $workloadDeploymentOutput.Count}
        else {$count = 1}
        for ($i = 0; $i -lt $count; $i++) {
            if ($workloadDeploymentOutput[$i].pstypenames[0] -eq 'Deserialized.Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment')
            {
                $workloadOutputArray = ($workloadDeploymentOutput[$i].OutputsString.Split()).Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            }
        }
    }

    ## ML Configuration (For this deployment the location of solution is pre-selected but can be changed by updating ML experiment information.)
    $mlLocationTable = @{
        "westcentralus" = "West Central US";
        "Integration Test" = "Integration Test";
        "germanycentral" = "Germany Central";
        "japaneast" = "Japan East";
        "southeastasia" = "Southeast Asia";
        "westeurope" = "West Europe";
        "southcentralus" = "South Central US"
    }

    log "Setting up experiment with following configuration"
    $expPackageUri = "https://storage.azureml.net/directories/0da451472661447797f947ce056df9a8/items"
    log "Experiment Package Uri - $expPackageUri"
    $expGalleryUri = "https://gallery.cortanaintelligence.com/Details/healthcare-blueprint-predictive-experiment-predicting-length-of-stay-in-hospitals"
    log " Experiment Gallery Uri - $expGalleryUri"
    $expEntityId = "Healthcare-Blueprint-Predictive-Experiment-Predicting-Length-of-Stay-in-Hospitals"
    log "Experiment Entity Id - $expEntityId"
    $expName = "Healthcare.Blueprint.Predictive Experiment - Predicting Length of Stay in Hospitals"
    log "Experiment Name - $expName"
    $mlWorspaceId = $workloadOutputArray[26]
    log "ML Workspace Id - $mlWorspaceId"
    $mlWorkspaceToken = $workloadOutputArray[23]
    log "ML Workspace Token - $mlWorkspaceToken"
    $mlWorkspaceLocation = $mlLocationTable.Item($workloadOutputArray[29])
    log "ML Workspace Location - $mlWorkspaceLocation"
    $mlWorkspaceUser = 'Debra_DataScientist@' + $tenantDomain
    log "ML Workspace User - $mlWorkspaceUser"

    # Import the AzureMLPS module. Additional information about the module can be found here - https://blogs.technet.microsoft.com/machinelearning/2016/05/04/announcing-the-powershell-module-for-azure-ml/
        
    #The module will provide access to Powershell to run ML cmdlets. 

    log "Importing AzureMLPS.dll from scripts\dlls"
    try {
        Unblock-File "$scriptroot\scripts\dlls\AzureMLPS.dll"
        Import-Module "$scriptroot\scripts\dlls\AzureMLPS.dll"
    } 
    catch {
        logerror
        Break
    }
    log "Importing AzureMLPS module completed"

    log "Check for any existing LoS predictive experiments in the ML WorkSpace.."
    if ($experiment = Get-AmlExperiment -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation | Where-Object Description -eq "$expName") {
        log "LoS predictive experiment $expName with Id - $($experiment.ExperimentId) exists."
        if ($experiment.Status.StatusCode -ne 'Finished') {
            log "LoS experiment found but was not initiated. Attempting to start AML experiment workspace."
            Start-AmlExperiment -ExperimentId $experiment.ExperimentId `
                -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        }
    }
    else {
        log "Copying the LoS predictive experiment into Azure ML workspace..."
        Copy-AmlExperimentFromGallery -PackageUri $expPackageUri -GalleryUri $expGalleryUri -EntityId $expEntityId `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        log "Copying the LoS predictive experiment completed"

        log "Starting the LoS predictive experiment workspace."
        $experiment = Get-AmlExperiment -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation `
        |   Where-Object Description -eq $expName
        Start-AmlExperiment -ExperimentId $experiment.ExperimentId `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        log "Experiment workspace has successfully started."
    }

    log "Adding User Debra_DataScientist to Azure ML workspace"
    if ((Get-AmlWorkspaceUsers -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation).Email -contains $mlWorkspaceUser) {
        log "AML Workspace User - $mlWorkspaceUser already exists."
    }
    else {
        Add-AmlWorkspaceUsers -Emails $mlWorkspaceUser -Role 'Owner' -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        log "Aml Workspace User - $mlWorkspaceUser added"
    }

    log "Check for existing ML Web Service for $expName and retrieve the endpoint"
    try {
        $webService = Get-AmlWebService -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation | Where-Object Name -eq "$expName"
        $endpoint = Get-AmlWebServiceEndpoint -WebServiceId $webservice.Id -EndpointName 'default' `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
    }
    catch {
        log "Exporting the ML Web Service..."
        $webService = New-AmlWebService -PredictiveExperimentId $experiment.ExperimentId `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        $endpoint = Get-AmlWebServiceEndpoint -WebServiceId $webservice.Id -EndpointName 'default' `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        log "Exporting the ML Web Service completed"
    }

    # Collecting ML information to be uploaded to Keyvault as secret.
    log "Uploading Azure ML LoS Web-Service-Endpoint & API-Key to Keyvault."
    $predictLengthOfStayServiceEndpoint = "$($endpoint.ApiLocation)/execute?api-version=2.0" # Variable used by pshfunction.ps1
    $predictLengthOfStayServiceApiKey = $endpoint.PrimaryKey # Variable used by pshfunction.ps1

    # Creating KeyVault Key to encrypt DB
    log "Trying to access Keyvault Key - $($workloadOutputArray[32]) using SiteAdmin account."
    $cnt = 0
    do {
        $cnt++
        try {
            Get-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -KeyName 'SQLTDEKEY'
            Break
        } 
        catch {
            log "Keyvault was unable to retrieve the key to be used for SQL TDE encryption $cnt of 3 tries."
            log "If Keyvault fails 3 times, the Azure resource has been exhausted. It is recommended that you wait for short time and re-run the deploy.ps1." Red
            $siteAdminContext = Login-AzureRmAccount -SubscriptionId $subscriptionId -TenantId $tenantId -Credential $siteAdmincredential -ErrorAction SilentlyContinue
            if($siteAdminContext -ne $null){
                log "Established connection to Alex_SiteAdmin Account." Green
            }
            Else{
                log "$($Error[0].Exception.Message)" Yellow
                log "Failed to connect to the Alex_SiteAdmin Account. Please login manually when prompted." Cyan
                Login-AzureRmAccount
            }
        }
        Start-Sleep 30
    } while ($cnt -lt 3)

    log "Access to Keyvault Keys successful."
    if (Get-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -KeyName 'SQLTDEKEY') {
        log "SQLTDEKEY already exist in Keyvault."
        log "Trying to access Keyvault - $($workloadOutputArray[32]) and retrieve SQLTDEKEY Information."
        $sqlServerTdeKeyObj = Get-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -KeyName 'SQLTDEKEY'
        $sqlTdeKeyUrl = $sqlServerTdeKeyObj.Id # Variable used by pshfunction.ps1
        log "SQLTDEKEY information retrieved successfully."
    }
    else {
        log "Create SQLTDEKEY in Keyvault - $($workloadOutputArray[32])."
        $sqlServerTdeKeyObj = Add-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -Name 'SQLTDEKEY' -Destination 'Software' # SQL TDE encryption key from keyvault does not support expiration date.
        $sqlTdeKeyUrl = $sqlServerTdeKeyObj.Id # Variable used by pshfunction.ps1
    }
    $sqlServerKeyName = ($sqlServerTdeKeyObj.VaultName, $sqlServerTdeKeyObj.Name, $sqlServerTdeKeyObj.Version) -join "_" # Variable used by pshfunction.ps1

    log "Deploying EventGrid and Update resources from scenarios/workload/update-resources/azuredeploy.json"
    Invoke-ARMDeployment -subscriptionId $subscriptionId -resourceGroupPrefix $deploymentPrefix -location $location -env $environment -steps 3

    # Pause Session for Background Job to Initiate.
    log "Waiting 20 seconds for background job to initiate"
    Start-Sleep 20

    #Get deployment status
    while ((Get-Job -Name '3-create' | Select-Object -Last 1).State -eq 'Running') {
        Get-ARMDeploymentStatus -jobName '3-create'
        Start-Sleep 10
    }

    if ((Get-Job -Name '3-create' | Select-Object -Last 1).State -eq 'Completed') 
    {
        Get-ARMDeploymentStatus -jobName '3-create'
        Start-Sleep 10
        log "Collect Update-Resources deployment Output."
        $updateResourcesDeploymentOutput = Get-AzureRmResourceGroupDeployment -ResourceGroupName $newDeploymentResourceGroupName -Name $newDeploymentName    
    }
    else
    {
        Get-ARMDeploymentStatus -jobName '3-create'
        log $error[0] -color Red
        log "Template deployment has failed. Go to Azure Portal / Subscription --> ResourceGroup <with prefix $deploymentPrefix> --> ResourceGroup Settings --> Deployments to troubleshoot the issue."
        Break
    }

    if($updateResourcesDeploymentOutput.OutputsString -eq $null){
        log "Critical failure occur in deploy.ps1. This can be corrected by re-running deploy.ps1" -color Red
        Break
    }
    else {
        $updateResourcesOutputArray = ($updateResourcesDeploymentOutput.OutputsString.Split()).Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
    }

    if($updateResourcesDeploymentOutput -eq $null){
        log "Critical failure occur in deploy.ps1. This can be corrected by re-running deploy.ps1" -color Red
        Break
    }
    else {
        $i = 0
        if($updateResourcesDeploymentOutput -is [system.array]){$count = $updateResourcesDeploymentOutput.Count}
        else {$count = 1}
        for ($i = 0; $i -lt $count; $i++) {
            if ($updateResourcesDeploymentOutput[$i].pstypenames[0] -eq 'Deserialized.Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment')
            {
                $updateResourcesOutputArray = ($updateResourcesDeploymentOutput[$i].OutputsString.Split()).Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            }
        }
    }

    # Importing the ML Training Experiment to traing ML algorithms.
    $trainingExpPackageUri = "https://storage.azureml.net/directories/6d85f91a126a4adb9c1073d01efa0175/items"
    $trainingExpGalleryUri = "https://gallery.cortanaintelligence.com/Details/healthcare-blueprint-predicting-length-of-stay-in-hospitals"
    $trainingExpEntityId = "Healthcare-Blueprint-Predicting-Length-of-Stay-in-Hospitals"
    $trainingExpName = "Healthcare.Blueprint-Predicting Length of Stay in Hospitals"

    log "Check for any existing LoS training experiment into Azure ML workspace."
    if ($experiment = Get-AmlExperiment -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation | Where-Object Description -eq "$trainingExpName") {
        log "LoS training experiment workspace $trainingExpName with Id - $($experiment.ExperimentId) exists."
        if ($experiment.Status.StatusCode -ne 'Finished') {
            log "LoS training experiment workspace found but not started. Attempting to start workspace."
            Start-AmlExperiment -ExperimentId $experiment.ExperimentId `
                -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        }
    }
    else {
        log "Copying the LoS training experiment into Azure ML workspace..."
        Copy-AmlExperimentFromGallery -PackageUri $trainingExpPackageUri -GalleryUri $trainingExpGalleryUri -EntityId $trainingExpEntityId `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        log "Copying the LoS training experiment workspace completed"
        
        log "Starting the Machine Learning training experiment workspace."
        $experiment = Get-AmlExperiment -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation `
        |    Where-Object Description -eq $trainingExpName
        Start-AmlExperiment -ExperimentId $experiment.ExperimentId `
            -WorkspaceId $mlWorspaceId -AuthorizationToken $mlWorkspaceToken -Location $mlWorkspaceLocation
        log "LoS training experiment workspace started"
    }

    #Create Patient DB Schema.
    log "Create patientdb table into database."
    $patientDbServerName = "tcp:$($workloadOutputArray[8]).database.windows.net"
	Invoke-Sqlcmd -Database patientdb -ServerInstance $patientDbServerName -EncryptConnection -Username sqlAdmin -Password $deploymentPassword -InputFile $scriptroot\scripts\sqlscripts\patientdb_schema.sql -QueryTimeout 60 -ConnectionTimeout 60 -OutputSqlErrors $true

	#Seed Metadata_Facilities
	Invoke-Sqlcmd -Database patientdb -ServerInstance $patientDbServerName -EncryptConnection -Username sqlAdmin -Password $deploymentPassword -InputFile $scriptroot\scripts\sqlscripts\patientdb_seed.sql -QueryTimeout 60 -ConnectionTimeout 60 -OutputSqlErrors $true

    # Invoke Sql Query to set DB level Firewall to Allow Azure Services to connect. To verify the firewall rule, execute 'select * from sys.database_firewall_rules' from ssms or sqll query editor.
    Invoke-Sqlcmd -Database patientdb -ServerInstance $patientDbServerName -EncryptConnection -Username sqlAdmin -Password $deploymentPassword -Query "EXECUTE sp_set_database_firewall_rule N'Allow Azure Services', '0.0.0.0', '0.0.0.0';" -QueryTimeout 60 -ConnectionTimeout 60 -OutputSqlErrors $true

    # Encrypting Patient information within database
    try {
        log "Encrypt Patient Information within SQL Database using EKM." Cyan
        # Connect to your database.
        $sqlsmodll = (Get-ChildItem "$env:programfiles\WindowsPowerShell\Modules\SqlServer" -Recurse -File -Filter "Microsoft.SqlServer.Smo.dll").FullName
        Add-Type -Path $sqlsmodll
        log "Connecting patientdb database."
        $connStr = "Server=tcp:$($workloadOutputArray[8]).database.windows.net,1433;Initial Catalog=patientdb;Persist Security Info=False;User ID=sqlAdmin;Password=$($workloadOutputArray[11]);MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $connection.ConnectionString = $connStr
        $connection.Connect()
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)
        $database = $server.Databases['patientdb']

        # Creating KeyVault Key to encrypt DB
        log "Create Keyvault Key for SQL Database Column Encryption."
        if (Get-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -KeyName 'SQLCEK') {
            $sqlCekKeyUrl = (Get-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -KeyName 'SQLCEK').Id
        }
        else {
            $sqlCekKeyUrl = (Add-AzureKeyVaultKey -VaultName $workloadOutputArray[32] -Name 'SQLCEK' -Destination 'Software' -Expires $expDateForKeyvaultKeysAndSecrets).Id
        }

        log "Create SQL Column Master Key (CMK) & Column Encryption Key (CEK) on Sql Server"
        $cmkName = "CMK"
        $cmkSettings = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyURL $sqlCekKeyUrl
        $sqlColumnMasterKey = Get-SqlColumnMasterKey -Name $cmkName -InputObject $database -ErrorAction SilentlyContinue
        if ($sqlColumnMasterKey){log "SQL Master Key $cmkName already exists."} 
        else{
            log "Create SQL Column Master Key - $sqlCekKeyUrl."
            New-SqlColumnMasterKey -Name $cmkName -InputObject $database -ColumnMasterKeySettings $cmkSettings
            log "SQL Column Master Key created."
        }

        log "Set Sql Azure authentication context using Application ID - $healthCareAdApplicationClientId."
        Add-SqlAzureAuthenticationContext -ClientID $healthCareAdApplicationClientId -Secret $deploymentPassword -Tenant $tenantId
        log "Sql Azure authentication context has been set."

        #Pausing session allowing SqlColumnMasterKey to be provisioned.
        Start-Sleep 10
        $cekName = "CEK"
        log "Checking if SqlColumnEncryptionKey - CEK already exists."
        $sqlColumnEncryptionKey = Get-SqlColumnEncryptionKey -Name 'CEK' -InputObject $database -ErrorAction SilentlyContinue
        Write-Host "Check completed."
        if ($sqlColumnEncryptionKey){log "SQL Column Encryption Key - $cekName already exists."}
        else {
            log "Create SQL Column Encryption Key."
            New-SqlColumnEncryptionKey -Name $cekName -InputObject $database -ColumnMasterKey $cmkName
            log "SQL Column Encryption Key created successfully."
        }

        log "Intiating Column Encryption for - FirstName, MiddleName, LastName."
        # Encrypt the selected columns (or re-encrypt, if they are already encrypted using keys/encrypt types, different than the specified keys/types.
        $ces = @()
        $ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.PatientData.FirstName" -EncryptionType "Deterministic" -EncryptionKey $cekName
        $ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.PatientData.MiddleName" -EncryptionType "Deterministic" -EncryptionKey $cekName
        $ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.PatientData.LastName" -EncryptionType "Deterministic" -EncryptionKey $cekName
        Set-SqlColumnEncryption -InputObject $database -ColumnEncryptionSettings $ces
        log "Column First Name, Middle Name & Last Name have been successfully encrypted."
    }
    catch {
        log "Column encryption failed an Azure resource has been exhausted. It is recommended that you wait for short time and re-run the deploy.ps1." Red
        log "Additional Error conditions are provided below." Red
        logerror
        Break
    }

    ### Creating Container to temporarily store training data.
    try {
        $storageContext = New-AzureStorageContext -StorageAccountName $workloadOutputArray[20] -StorageAccountKey $workloadOutputArray[14]
        log  "Connecting to $($storageContext.BlobEndPoint). Creating storage container - 'trainingdata'"
        New-AzureStorageContainer -Name "trainingdata" -Permission Off -Context $storageContext
    }
    catch {
        log " Blobstorage - $($storageContext.BlobEndPoint) - Container 'trainingdata' already exists."
    }

    # Starting OMS Diagnostics
    log "Getting OMS Workspace details."
    $omsWS = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $monitoring.ResourceGroupName

    log "Collecting list of resourcetype to enable log analytics."
    $resourceTypes = @( 
        "Microsoft.Web/serverFarms",
        "Microsoft.Web/sites"
    )

    foreach($resourceType in $resourceTypes)
    {
        log "Enabling diagnostics for - $resourceType starting \scripts\pshscripts\Enable-AzureRMDiagnostics.ps1."
        & "$scriptroot\scripts\pshscripts\Enable-AzureRMDiagnostics.ps1" -WSID $omsWS.ResourceId -SubscriptionId $subscriptionId -ResourceType $resourceType -ResourceGroup $workload.ResourceGroupName -EnableLogs -EnableMetrics -Force
    }

    log "Provisioning users. Launching Configure-AADUsers.ps1, waiting 40 seconds for provisioning to complete." Cyan

    log "Enabling Diagnostics for Storage Accounts. Provisioning will take up to 10 minutes."
    $workloadResourceGroupName = (($deploymentPrefix, 'workload', $environment, 'rg') -join '-')
    $deploymentStorageAccounts = Get-AzureRmResource | Where-Object {($_.ResourceType -eq 'Microsoft.Storage/storageAccounts') -and ($_.ResourceGroupName -match $workloadResourceGroupName)}
    $deploymentStorageAccounts | ForEach-Object {
        $storageAccessKey = ($_ | Get-AzureRmStorageAccountKey).Value[0]
        $storageContext = New-AzureStorageContext -StorageAccountName $_.Name -StorageAccountKey $storageAccessKey
        $serviceTypes = @('Blob', 'Table', 'Queue', 'File')
        foreach ($serviceType in $serviceTypes) {
            Set-AzureStorageServiceMetricsProperty -ServiceType $serviceType -MetricsType Hour -Context $storageContext `
            -MetricsLevel 'ServiceAndApi' -PassThru -RetentionDays 365 -Version 1.0 -ErrorAction SilentlyContinue | Out-Null
    
            Set-AzureStorageServiceLoggingProperty -ServiceType $serviceType -LoggingOperations All -Context $storageContext `
            -PassThru -RetentionDays 365 -Version 1.0 -ErrorAction SilentlyContinue | Out-Null
        }
    }
    log "Diagnostics enabled on Storage Accounts."

    Get-AzureRmResource | Where-Object {($_.ResourceType -eq 'Microsoft.Storage/storageAccounts') `
    -and ($_.ResourceGroupName -match $workloadResourceGroupName) `
    -and ($_.Name -notmatch $deploymentPrefix)} -OutVariable artifactsStorageAccount | `
    Remove-AzureRmResource -Force 
    log "Deleting temporary storage account - $($artifactsStorageAccount.ResourceName)."

    # Enable ASC Policies

    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    log "Checking AzureRM context for Azure security center configuration."
    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)

    log "Getting access token for Azure security center."
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
    $token = $token.AccessToken
    $Script:asc_clientId = "1950a258-227b-4e31-a9cf-717495945fc2"              # Well-known client ID for Azure PowerShell
    $Script:asc_redirectUri = "urn:ietf:wg:oauth:2.0:oob"                      # Redirect URI for Azure PowerShell
    $Script:asc_resourceAppIdURI = "https://management.azure.com/"             # Resource URI for REST API
    $Script:asc_url = 'management.azure.com'                                   # Well-known URL endpoint
    $Script:asc_version = "2015-06-01-preview"                                 # Default API Version
    $PolicyName = 'default'
    $asc_APIVersion = "?api-version=$asc_version" #Build version syntax.
    $asc_endpoint = 'policies' #Set endpoint.

    log "Creating authentication header."
    Set-Variable -Name asc_requestHeader -Scope Script -Value @{"Authorization" = "Bearer $token"}
    Set-Variable -Name asc_subscriptionId -Scope Script -Value $currentAzureContext.Subscription.Id

    #Retrieve existing policy and build hashtable
    log "Retrieving data for $PolicyName..."
    $asc_uri = "https://$asc_url/subscriptions/$asc_subscriptionId/providers/microsoft.Security/$asc_endpoint/$PolicyName$asc_APIVersion"
    $asc_request = Invoke-RestMethod -Uri $asc_uri -Method Get -Headers $asc_requestHeader
    $a = $asc_request 
    $json_policy = @{
        properties = @{
            policyLevel = $a.properties.policyLevel
            policyName = $a.properties.name
            unique = $a.properties.unique
            logCollection = $a.properties.logCollection
            recommendations = $a.properties.recommendations
            logsConfiguration = $a.properties.logsConfiguration
            omsWorkspaceConfiguration = $a.properties.omsWorkspaceConfiguration
            securityContactConfiguration = $a.properties.securityContactConfiguration
            pricingConfiguration = $a.properties.pricingConfiguration
        }
    }
    if ($json_policy.properties.recommendations -eq $null){Write-Error "Azure security center has stopped responding, Azure resource has been exhausted. It is recommended that you wait for short time and re-run the deploy.ps1."; return}

    #Set all params to on,
    $json_policy.properties.recommendations.patch = "On"
    $json_policy.properties.recommendations.baseline = "On"
    $json_policy.properties.recommendations.antimalware = "On"
    $json_policy.properties.recommendations.diskEncryption = "On"
    $json_policy.properties.recommendations.acls = "On"
    $json_policy.properties.recommendations.nsgs = "On"
    $json_policy.properties.recommendations.waf = "On"
    $json_policy.properties.recommendations.sqlAuditing = "On"
    $json_policy.properties.recommendations.sqlTde = "On"
    $json_policy.properties.recommendations.ngfw = "On"
    $json_policy.properties.recommendations.vulnerabilityAssessment = "On"
    $json_policy.properties.recommendations.storageEncryption = "On"
    $json_policy.properties.recommendations.jitNetworkAccess = "On"
    $json_policy.properties.recommendations.appWhitelisting = "On"
    $json_policy.properties.securityContactConfiguration.areNotificationsOn = $true
    $json_policy.properties.securityContactConfiguration.sendToAdminOn = $true
    $json_policy.properties.logCollection = "On"
    $json_policy.properties.pricingConfiguration.selectedPricingTier = "Standard"
    try {
        $json_policy.properties.securityContactConfiguration.securityContactEmails = $siteAdminUserName
    }
    catch {
        $json_policy.properties.securityContactConfiguration | Add-Member -NotePropertyName securityContactEmails -NotePropertyValue $siteAdminUserName
    }
    Start-Sleep 5

    log "Enabling ASC Policies.."
    $JSON = ($json_policy | ConvertTo-Json -Depth 3)
    $asc_uri = "https://$asc_url/subscriptions/$asc_subscriptionId/providers/microsoft.Security/$asc_endpoint/$PolicyName$asc_APIVersion"
    $result = Invoke-WebRequest -Uri $asc_uri -Method Put -Headers $asc_requestHeader -Body $JSON -UseBasicParsing -ContentType "application/json"
    ($json_policy.properties.recommendations).PSObject.Properties | foreach-object { $name = $_.Name; $value = $_.value; log "$name = $value"}

    # Add values to hashtable
    $outputTable.Add('DeploymentPassword',$deploymentPassword)
    $outputTable.Add('BlobStorageAccountName',$workloadOutputArray[20])
    $outputTable.Add('UPN_DataScientistUser',$mlWorkspaceUser)
    $outputTable.Add('AADApplicationClientId',$healthCareAdApplicationClientId)
    $outputTable.Add('UPN_SiteAdminUser', ('Alex_SiteAdmin@' + $tenantDomain))
    $outputTable.Add('UPN_DBAnalystUser',('Danny_DBAnalyst@' + $tenantDomain))
    $outputTable.Add('UPN_AuditorUser',('Han_Auditor@' + $tenantDomain))
    $outputTable.Add('UPN_CMIOUser',('Caroline_ChiefMedicalInformationOfficer@' + $tenantDomain))
    $outputTable.Add('UPN_CLMUser',('Chris_CareLineManager@' + $tenantDomain))
    $outputTable.Add('AzFunc_AdmissionFunctionUrl',$updateResourcesOutputArray[8])
    $outputTable.Add('AzFunc_DischargeFunctionUrl',$updateResourcesOutputArray[11])
    $outputTable.Add('AzFunc_LearnFunctionUrl',$updateResourcesOutputArray[14])
    $outputTable.Add('AADTenantId', $tenantId)
    $outputTable.Add('AADAppReplyUrl', $replyUrl)
    $outputTable.Add('AADApplication', $displayName)
    $outputTable.Add('SQLServerLocalAccount', 'sqlAdmin')
    $outputTable.Add('SQLPatientDbConnectionString', $workloadOutputArray[41..46] -join '')
    $outputTable.Add('SQLPatientDatabaseName', $workloadOutputArray[49])
    $outputTable.Add('SQLServerFqdn', $workloadOutputArray[38])
    $servicePrincipalIteration = 1
    Get-AzureRmADServicePrincipal -SearchString $deploymentPrefix | ForEach-Object {
        $outputTable.Add("AADServicePrincipal$servicePrincipalIteration", $_.DisplayName )
        $servicePrincipalIteration++
    }

    if (($enableADDomainPasswordPolicy -eq $true) -and ($enableMFA -eq $false)) {
        log "Initialising powershell session to enable Domain Password Policy. NOTE: Configure-Msol.ps1 will open a powershell window that you must close when completed."
        Start-Process Powershell -ArgumentList "-NoExit", "-WindowStyle Minimized", "-ExecutionPolicy UnRestricted", ".\scripts\pshscripts\Configure-Msol.ps1 -tenantId $tenantId -subscriptionId $subscriptionId -tenantDomain $tenantDomain -globalAdminUsername $siteAdminUserName -globalAdminPassword '$deploymentPassword' -enableADDomainPasswordPolicy"
        log "Configuring with domain password policy. Launching Configure-Msol.ps1, waiting 60 seconds for provisioning to complete." Cyan
        log "Waiting for MSOL to be configured with domain password policy."
        Start-Sleep 60
    }
    elseif (($enableADDomainPasswordPolicy -eq $false) -and ($enableMFA -eq $true)) {
        log "Initialising powershell session to enable Multi-Factor Authentication. NOTE: Configure-Msol.ps1 will open a powershell window that you must close when completed."
        Start-Process Powershell -ArgumentList "-NoExit", "-WindowStyle Minimized", "-ExecutionPolicy UnRestricted", ".\scripts\pshscripts\Configure-Msol.ps1 -tenantId $tenantId -subscriptionId $subscriptionId -tenantDomain $tenantDomain -globalAdminUsername $siteAdminUserName -globalAdminPassword '$deploymentPassword' -enableMFA"
        log "Configuring with multi-factor authentication. Launching Configure-Msol.ps1, waiting 60 seconds for provisioning to complete." Cyan
        Start-Sleep 60
    }
    elseif (($enableADDomainPasswordPolicy) -and ($enableMFA)) {
        log "Initialising powershell session to enable Domain Password Policy and Multi-Factor Authentication. NOTE: Configure-Msol.ps1 will open a powershell window that you must close when completed."
        Start-Process Powershell -ArgumentList "-NoExit", "-WindowStyle Minimized", "-ExecutionPolicy UnRestricted", ".\scripts\pshscripts\Configure-Msol.ps1 -tenantId $tenantId -subscriptionId $subscriptionId -tenantDomain $tenantDomain -globalAdminUsername $siteAdminUserName -globalAdminPassword '$deploymentPassword' -enableADDomainPasswordPolicy -enableMFA"
        log "Configuring with domain password policy and multi-factor authentication.. Launching Configure-Msol.ps1, waiting 60 seconds for provisioning to complete." Cyan
        Start-Sleep 60
    }

    log "Finalising deployment and generating output json - $($deploymentPrefix)-deploymentOutput.json."

    ## Store deployment output to CloudDrive folder else to Output folder.
    if (Test-Path -Path "$HOME\CloudDrive") {
        log "CloudDrive was found. Saving $($deploymentPrefix)-deploymentOutput.json & $logFileName to CloudDrive.."
        $outputTable | ConvertTo-Json | Out-File -FilePath "$HOME\CloudDrive\$($deploymentPrefix)-deploymentOutput.json"
        Get-ChildItem $outputFolderPath -File -Filter *.txt | Copy-Item -Destination  "$HOME\CloudDrive\"
        log "Output file has been generated - $HOME\CloudDrive\$($deploymentPrefix)-deploymentOutput.json." Green
        #Get-Content "$HOME\CloudDrive\$($deploymentPrefix)-deploymentOutput.json"
        $outputTable.GetEnumerator() | Sort-Object -Property Name | Format-Table -AutoSize -Wrap
    }
    Else {
        log "CloudDrive was not found. Saving deploymentOutput.json to Output folder.."
        $outputTable | ConvertTo-Json | Out-File -FilePath "$outputFolderPath\$($deploymentPrefix)-deploymentOutput.json"
        log "Output file has been generated - $outputFolderPath\$($deploymentPrefix)-deploymentOutput.json." Green
        #Get-Content "$outputFolderPath\$($deploymentPrefix)-deploymentOutput.json"
        $outputTable.GetEnumerator() | Sort-Object -Property Name | Format-Table -AutoSize -Wrap
    }
}
#### END OF SCRIPT ###