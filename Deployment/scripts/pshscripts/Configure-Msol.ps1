<#

.SYNOPSIS
    Connects the MS Online Active Directory and Enabling Password Policy, Multi-Factor Authentication.

.DESCRIPTION
    Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.EXAMPLE
    Configure-Msol.ps1 -tenantId <tenantId> `
        -subscriptionId <subscriptionId> `
        -tenantDomain <tenantDomain> `
        -globalAdminUsername <globalAdminUsername> `
        -globalAdminPassword <globalAdminPassword> `
        -enableADDomainPasswordPolicy <switch>
    This command will enable Active Domain password policy and set expiry for 60 days.

.EXAMPLE
    Configure-Msol.ps1 -tenantId <tenantId> `
        -subscriptionId <subscriptionId> `
        -tenantDomain <tenantDomain> `
        -globalAdminUsername <globalAdminUsername> `
        -globalAdminPassword <globalAdminPassword> `
        -enableMFA <switch>
    This command will enable Multi-Factor Authentication for the users.

.EXAMPLE
    Configure-Msol.ps1 -tenantId <tenantId> `
        -subscriptionId <subscriptionId> `
        -tenantDomain <tenantDomain> `
        -globalAdminUsername <globalAdminUsername> `
        -globalAdminPassword <globalAdminPassword> `
        -enableADDomainPasswordPolicy <switch> `
        -enableMFA <switch>
    This command will enable Active Domain password policy and set expiry for 60 days, enables Multi-Factor Authentication.

#>

[CmdletBinding()]
param
(
    #Azure AD Tenant Id.
    [Parameter(Mandatory = $true,
        ParameterSetName = "Deployment",
        Position = 1)]
    [guid]$tenantId,

    #Azure Subscription Id.
    [Parameter(Mandatory = $true,
        ParameterSetName = "Deployment",
        Position = 2)]
    [Alias("subId")]
    [guid]$subscriptionId,

    #Azure Tenant Domain name.
    [Parameter(Mandatory = $true,
        ParameterSetName = "Deployment",
        Position = 3)]
    [Alias("domain")]
    [ValidatePattern("[.]")]
    [string]$tenantDomain,

    #Subcription GlobalAdministrator Username.
    [Parameter(Mandatory = $true,
        ParameterSetName = "Deployment",
        Position = 4)]
    [Alias("userName")]
    [string]$globalAdminUsername,

    #GlobalAdministrator Password in a plain text.
    [Parameter(Mandatory = $true,
        ParameterSetName = "Deployment",
        Position = 5)]
    [Alias("password")]
    [string]$globalAdminPassword,

    #Switch enables password policy to expire after 60 days at domain level.
    [Parameter(Mandatory = $false,
        ParameterSetName = "Deployment",
        Position = 7)]
    [switch]$enableADDomainPasswordPolicy,
    
    #Switch enables multi-factor authentication for deployed user accounts.
    [Parameter(Mandatory = $false,
        ParameterSetName = "Deployment",
        Position = 8)]
    [switch]$enableMFA

)
# Set Domain Level Password Policy and Enable MultiFactor Authentication.
try {
    ### Manage Session Configuration
    $Host.UI.RawUI.WindowTitle = "HealthCare - Configure MSOL"
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 3
    $deploymentFolderPath = Split-Path(Split-Path -Path $PSScriptRoot)

    ### Create Output folder to store logs, deployment files.
    if (! (Test-Path -Path "$deploymentFolderPath\output")) {
        New-Item -Path $deploymentFolderPath -Name 'output' -ItemType Directory
    }
    $outputFolderPath = "$deploymentFolderPath\output"

    # Configure transcript
    Write-Host "Initiating transcript to log session."
    Start-Transcript -OutputDirectory $outputFolderPath -Force

    ### Verifying required powershell modules for enabling password policies and MFA.
    $requiredModules = @{
        'AzureRM'  = '4.4.0';
        'AzureAD'  = '2.0.0.131';
        'MSOnline' = '1.1.166.0'
    }
    $modules = $requiredModules.Keys
    try {
        foreach ($module in $modules) {
            Write-Host -ForegroundColor Yellow "Importing module - $module."
            Import-Module -Name $module -RequiredVersion $requiredModules[$module]
            if (Get-Module -Name $module) {
                Write-Host -ForegroundColor Green "Module - $module imported successfully."
            }
        }
    }
    catch {
        Write-Host "Please run 'deploy.ps1 -installModules' switch." -foregroundcolor Cyan
        Break
    }
    # The following will setup the usecase users that will be used throughout the Blueprint.
    $users = @('Alex_SiteAdmin', 'Danny_DBAnalyst', 'Caroline_ChiefMedicalInformationOfficer', 'Chris_CareLineManager', 'Han_Auditor', 'Debra_DataScientist')

    try {
        ### Create PSCredential Object
        $password = ConvertTo-SecureString -String $globalAdminPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($globalAdminUsername, $password)

        # Connecting to MSOL Service
        Write-Host -ForegroundColor Yellow "Establishing connection to MS Online (MSOL) Service for setting up password policy."
        Write-Host -ForegroundColor Yellow "Connecting to MSOL service."
        Connect-MsolService -Credential $credential
    }
    catch {
        Connect-MsolService
    }

    try {
        Get-MsolDomain
        Write-Host -ForegroundColor Green "Connection to MSOL Service established."
    }
    catch {
        Throw $_
    }

    if ($enableADDomainPasswordPolicy) {
        Write-Host -ForegroundColor Yellow "Setting up password policy for $tenantDomain domain"
        Set-MsolPasswordPolicy -ValidityPeriod 60 -NotificationDays 14 -DomainName "$tenantDomain"
        if ((Get-MsolPasswordPolicy -DomainName $tenantDomain).ValidityPeriod -eq 60 ) {
            Write-Host -ForegroundColor Green "Password policy has been set to expire in 60 Days."
        }
        else {
            Write-Host -ForegroundColor Red "Failed to set password policy."
        }
    }
    if ($enableMFA) {
        foreach ($user in $users) {
            $upn = $user + '@' + $tenantDomain
            $strongAuthObj = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement 
            $strongAuthObj.RelyingParty = "*" 
            $strongAuthObj.State = 'Enabled' 
            Write-Host -ForegroundColor Yellow "Enabling Multi-Factor Authentication for $upn"
            Set-MsolUser -UserPrincipalName $upn -StrongAuthenticationRequirements $strongAuthObj
            Write-Host -ForegroundColor Yellow "Multi-Factor Authentication enabled."
        }
    }
}
catch {
    Throw $_
}