<#
.SYNOPSIS
    Connects AzureAD and Create User accounts.
.EXAMPLE
    configureAADUsers.ps1 -tenantId <Tenant Id> -subscriptionId <Subscription Id> -tenantDomain <Tenant Domain Name> `
    -globalAdminUsername <Service or Global Administrator Username> -globalAdminPassword <Service or Global Administrator Password> `
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
    [Parameter(Mandatory = $true)]
    [string]$globalAdminUsername,
    [Parameter(Mandatory = $true)]
    [string]$globalAdminPassword,
    [Parameter(Mandatory = $true)]
    [string]$deploymentPassword
)

### Manage Session Configuration
$Host.UI.RawUI.WindowTitle = "HealthCare - Configure AAD Users"
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

### Create PSCredential Object
$password = ConvertTo-SecureString -String $globalAdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($globalAdminUsername,$password)

### Connect AzureAD
Import-Module AzureAD
Connect-AzureAD -Credential $credential -TenantId $tenantId
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
Write-Host -ForegroundColor Cyan "AAD Users provisioned. Powershell window can be closed."