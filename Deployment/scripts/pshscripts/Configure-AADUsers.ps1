<#
.SYNOPSIS
    Connects AzureAD and Create User accounts.

.DESCRIPTION
    Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    
.EXAMPLE
    configureAADUsers.ps1 -tenantId <Tenant Id> `
        -subscriptionId <Subscription Id> `
        -tenantDomain <Tenant Domain Name> `
        -globalAdminUsername <Service or Global Administrator Username> `
        -globalAdminPassword <Service or Global Administrator Password> `
        -deploymentPassword <Strong Password>
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]	
    [guid]$tenantId,
    [Parameter(Mandatory = $true)]
    [guid]$subscriptionId,
    [Parameter(Mandatory = $true)]
    [string]$tenantDomain,
    [Parameter(Mandatory = $false)]
    [string]$globalAdminUsername = 'null',
    [Parameter(Mandatory = $false)]
    [string]$globalAdminPassword = 'null',
    [Parameter(Mandatory = $true)]
    [string]$deploymentPassword
)

### Manage Session Configuration
$Host.UI.RawUI.WindowTitle = "HealthCare - Configure AAD Users"
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

### Connect AzureAD
Import-Module AzureAD

### Connect to AzureAD
if ($globalAdminUsername -eq 'null') {
    Write-Host "`nYou will be prompted for manual login. Enter your credentials to continue.`n" -ForegroundColor Cyan
    Connect-AzureAD -TenantId $tenantId
}
else {
    ### Create PSCredential Object
    $password = ConvertTo-SecureString -String $globalAdminPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($globalAdminUsername,$password)
    Connect-AzureAD -Credential $credential -TenantId $tenantId
}

### Create user password profile.
$passwordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$passwordProfile.Password = $deploymentPassword
$passwordProfile.ForceChangePasswordNextLogin = $false

### Create Active Directory Users
$actors = @('Alex_SiteAdmin','Danny_DBAnalyst','Caroline_ChiefMedicalInformationOfficer','Chris_CareLineManager','Han_Auditor','Debra_DataScientist')
foreach ($user in $actors) {
    $upn = $user + '@' + $tenantDomain
    Write-Host -ForegroundColor Yellow "`nChecking if $upn exists in AAD."
    if (!(Get-AzureADUser -SearchString $upn))
    {
        Write-Host -ForegroundColor Green  "`n$upn does not exist in the directory. Creating account for $upn."
        try {
            $userObj = New-AzureADUser -DisplayName $user -PasswordProfile $passwordProfile `
            -UserPrincipalName $upn -AccountEnabled $true -MailNickName $user
            Write-Host -ForegroundColor Yellow "`n$upn created successfully."
            if ($upn -eq ('Alex_SiteAdmin@'+$tenantDomain)) {
            #Get the Compay AD Admin ObjectID
            $companyAdminObjectId = Get-AzureADDirectoryRole | Where-Object {$_."DisplayName" -eq "Company Administrator"} | Select-Object ObjectId
            #Make the new user the company admin aka Global AD administrator
            Add-AzureADDirectoryRoleMember -ObjectId $companyAdminObjectId.ObjectId -RefObjectId $userObj.ObjectId
            Write-Host "`nSuccessfully granted Global AD permissions to $upn" -ForegroundColor Yellow
            }
        }
        catch {
            throw $_
        }
    }
    else {
        Write-Host -ForegroundColor Green  "`n$upn already exists in AAD. Resetting password.."
        Get-AzureADUser -SearchString $upn | Set-AzureADUser -PasswordProfile $passwordProfile
    }
}
Write-Host -ForegroundColor Cyan "`nAAD Users provisioned. Powershell window can be closed."