<#

.DESCRIPTION
    Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#>

# Set Variables, Hashtable, Arrays.
$Error.Clear()
$ProfilePath = "$scriptRoot\auth.json"
$Script:uniqueDeploymentId = New-Guid
$scriptRoot = Split-Path (Split-Path ( Split-Path $MyInvocation.MyCommand.Path ))
$sqlTdeKeyUrl = "auto-update"
$sqlServerKeyName = "auto-update"
$predictLengthOfStayServiceEndpoint = "auto-update"
$predictLengthOfStayServiceApiKey = "auto-update"
$Script:expDateForKeyvaultKeysAndSecrets = (Get-Date).AddYears(1).ToUniversalTime()
$unixTimeStamp = [int64]($expDateForKeyvaultKeysAndSecrets - (get-date "1/1/1970")).TotalSeconds

<#
.SYNOPSIS
    Converts String into Hash Value.
#>
Function Get-StringHash([String]$String, $HashName = "SHA1") { # This hash name is one time hash used for identify this script deployment is unique.
    $StringBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| 
        ForEach-Object { [Void]$StringBuilder.Append($_.ToString("x2"))
    }
    $StringBuilder.ToString().Substring(0, 24)
}

$Script:uniqueDeploymentHash = (Get-StringHash $uniqueDeploymentId).Substring(0,5)

<#
.SYNOPSIS
    Logs errors to the logfile.
#>
function logerror {
    $errors = $Error.ToArray()
    [array]::Reverse($errors)
    foreach ($err in $errors){
        if ($err -match ' PM - '){
            $logMessage = ($err -split ' PM - ')[1]
        }
        elseif ($err -match ' AM -'){
            $logMessage = ($err -split ' AM - ')[1]
        }
        else{
            $logMessage = $err
        }
        $err
        log "$logMessage" -color Red -suppress
    }
    $error.Clear()
}

<#
.SYNOPSIS
    Function to write output to log file and display on the host with timestamp.
.EXAMPLE
    log -statement "This is an example"
.EXAMPLE
    log -statement "This is an example" -color 'yellow' -displaywithouttimestamp
.EXAMPLE
    log -statement "This is an example" -color 'yellow' -suppress
.EXAMPLE
    log -statement "This is an example" -color 'yellow' -displaywithouttimestamp -nonewline
#>
function log {
    [CmdletBinding()]
    param (
        #Value to be logged and printed on host.
        [Parameter(Mandatory=$true,
        ParameterSetName = "log",
        Position=0)]
        [Parameter(Mandatory=$true,
        ParameterSetName = "printwithouttimestamp",
        Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $statement,

        #Displal color for the printed value.
        [Parameter(Mandatory=$false,
        ParameterSetName = "log",
        Position=1)]
        [Parameter(Mandatory=$false,
        ParameterSetName = "printwithouttimestamp",
        Position=1)]
        $color = 'Yellow',

        #Switch to log the value but suppress printed value on host.
        [Parameter(Mandatory=$false,
        ParameterSetName = "log",
        Position=2)]
	    [switch]
        $suppress,

        #Switch to display printed value without timestamp.
        [Parameter(Mandatory=$true,
        ParameterSetName = "printwithouttimestamp",
        Position=2)]
	    [switch]
        $displaywithouttimestamp,

        #Switch to display printed value without timestamp and no new line.
        [Parameter(Mandatory=$false,
        ParameterSetName = "printwithouttimestamp",
        Position=3)]
	    [switch]
        $nonewline
    )
    process {
        $error.Clear()
        $logFolderPath = $outputFolderPath #Set the log path here.
        $logtime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logHash = $uniqueDeploymentHash
        $Script:logFileName = (($deploymentPrefix,"HealthCare$logHash",(Get-Date -Format 'yyyy-MM-dd').ToString(),'log.txt') -join '-')
        $filePath = $logFolderPath + '\' +$logFileName
        if (!(Test-Path -Path $filePath)){
            New-Item -Path $logFolderPath -Name $logFileName -ItemType File | Out-Null
            Write-Host -ForegroundColor $color "`nLog file created - $filePath`n"
        }
        "$logtime - $statement" | Out-File $filePath -Append -Encoding ascii
        if ($suppress){
            $null
        }
        else {
            if ($displaywithouttimestamp){
                if($nonewline) {
                    Write-Host "$($statement)" -ForegroundColor $color
                }
                else {
                    Write-Host "`n$($statement)" -ForegroundColor $color
                }
            }
            else {
                Write-Host "`n$($logtime) - $($statement)" -ForegroundColor $color
            }
        }
    }
}

<#
.SYNOPSIS
    Function installs required modules for Blueprint.
.EXAMPLE
    PS C:\> $requiredModules=@{'AzureRM' = '4.4.0';'AzureAD' = '2.0.0.131';'SqlServer' = '21.0.17178';'MSOnline' = '1.1.166.0'}
    Hashtable created with required versions and modules.

    PS C:\> Install-RequiredModules -moduleNames $requiredModules
    Missing modules are installed.
#>
function Install-RequiredModules {
    param
    (
        #Modules hashtable
        [Parameter(Mandatory=$true, 
	    ValueFromPipelineByPropertyName=$true,
        Position=0,
        HelpMessage="Enter modules hashtable")]
	    [ValidateNotNullOrEmpty()]
	    [hashtable]
        $moduleNames
	)
	Process
		{
            try {
                $modules = $moduleNames.Keys
                foreach ($module in $modules){
                    $requiredModuleVersion = $moduleNames[$module]
                    log "Verifying module status $module."
                    if (!(Get-InstalledModule $module -ErrorAction SilentlyContinue)){
                        log "Module $module is not installed."
                        Install-Module $module -RequiredVersion $moduleNames[$module] -Force -AllowClobber
                        log "Module $module installed successfully."
                    }
                    elseif((Get-InstalledModule $module).Version.ToString() -ne $moduleNames[$module]){
			            $installedModuleVersion = (Get-InstalledModule $module).Version.ToString()
                        log "Version $installedModuleVersion found, Installing version $requiredModuleVersion."
                        if (Install-Module $module -RequiredVersion $moduleNames[$module] -Force -AllowClobber){
                            log "Module $module installed."
                        }
                    }
                    else {
                        log "Version $requiredModuleVersion is installed."
                    }
                }
            }
            catch {
                logerror
                Break
            }
		}
}

<#
.SYNOPSIS
    This function reads subscription.roleassignments.json and assign appropriate roles to the users. Normalising strings 
    and adding environmental variables in the roles.
#>
function Update-RoleAssignments {
    [CmdletBinding()]
    [OutputType([int])]
    param
    (
        # <!<SnippetParam1Help>!>
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [System.IO.FileInfo]$inputFile,

        # <!<SnippetParam2Help>!>
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        [String]$prefix,

        # <!<SnippetParam2Help>!>
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=2)]
        [String]$env,

        # <!<SnippetParam2Help>!>
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=3)]
        [String]$domain
	)

    Process
    {
		$jsonObj = Get-Content $inputFile
		$jsonObj = $jsonObj -replace 'hash', $prefix
		$jsonObj = $jsonObj -replace 'env', $env
		$jsonObj | Out-File $env:Temp\roleassignments.json -Force 
		$jsonObj = Get-Content $env:Temp\roleassignments.json | ConvertFrom-Json
		$users = ($jsonObj.UserConfiguration).PSObject.Properties.Name
		foreach ($user in $users) {
			$upn = $user + '@' + $domain
			$userProperties = $jsonObj.UserConfiguration | Select-Object -ExpandProperty $user
			$userProperties.PSObject.Properties.Name | ForEach-Object{
				if ($_ -eq 'ResourceGroup') {
					$rgRoles = $userProperties.PSObject.Properties | Where-Object Name -eq 'ResourceGroup'
					$rgRoles.Value.Name | ForEach-Object {
						$rgName = $_
						($rgRoles.Value | ? name -eq $rgName ).role.name | ForEach-Object {
							log "Assigning $upn with Role $_ on ResourceGroup $rgName."
                            try {
                                New-AzureRmRoleAssignment -SignInName $upn -ResourceGroupName $rgName -RoleDefinitionName "$_"
                            }
                            catch {
                                log $_.Exception.Message Green
                            }
						}
					}
				}
				elseif ($_ -eq 'Subscription') {
					$subscriptionId = $jsonObj.Subscription.Id
					$subRoles = $userProperties.PSObject.Properties | ? Name -eq 'Subscription'
					($subRoles.Value).role.name | ForEach-Object {
                        log "Assigning $upn with Role $_ on Subsciption $subscriptionId."
                        try {
                            New-AzureRmRoleAssignment -SignInName $upn -RoleDefinitionName "$_" -Scope "/subscriptions/$subscriptionId"
                        }
                        catch {
                            log $_.Exception.Message Green
                        }
					}
				}
				else {
					log "User $upn does not have any role assignments defined."
				}
			}
		}
    }
}

<#
.SYNOPSIS
    This function invokes ARM deployment as a background job, verifies strings used in deployment. 
#>
function Invoke-ARMDeployment {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [guid]$subscriptionId,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [ValidateScript( {$_ -notmatch '\s+' -and $_ -match '[a-zA-Z0-9]+'})]
        [string]$resourceGroupPrefix,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [string]$location,
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
        [ValidateSet("dev", "prod")]
        [string]$env = 'dev',
        [Parameter(Mandatory = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 4)]
        [int[]]$steps,
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 5)]
        [switch]$prerequisiteRefresh
    )
    $null = Save-AzureRmContext -Path $ProfilePath -Force
    try {
        $deploymentHash = Get-StringHash(($subscriptionId, $resourceGroupPrefix, $env) -join '-')
        if ($prerequisiteRefresh) {
            Publish-BuildingBlocksTemplates $deploymentHash
        }
        $deploymentData = Get-DeploymentData $deploymentHash
        $deployments = @{
            1 = @{"name" = "monitoring"; "rg" = "monitoring"}
            2 = @{"name" = "workload"; "rg" = "workload"};
            3 = @{"name" = "workload\update-resources"; "rg" = "workload"}
        }
        foreach ($step in $steps) {
            $importSession = {
                param(
                    $rgName,
                    $pathTemplate,
                    $pathParameters,
                    $deploymentName,
                    $scriptRoot,
                    $subscriptionId
                )
                try {
                    Import-AzureRmContext -Path "$scriptRoot\auth.json" -ErrorAction Stop
                    Set-AzureRmContext -SubscriptionId $subscriptionId
                }
                catch {
                    # Critical failure was detected. Exiting script.
                    Write-Error $_
                    exit 1337
                }
                New-AzureRmResourceGroupDeployment `
                    -ResourceGroupName $rgName `
                    -TemplateFile $pathTemplate `
                    -TemplateParameterFile $pathParameters `
                    -Name $deploymentName `
                    -ErrorAction Stop -Verbose 4>&1
            }.GetNewClosure()
            $Script:newDeploymentName = (($deploymentData[0], ($deployments.$step).name) -join '-').ToString().Replace('\','-')
            $Script:newDeploymentResourceGroupName = (($resourceGroupPrefix,($deployments.$step).rg,$env,'rg' ) -join '-')
            Start-job -Name ("$step-create") -ScriptBlock $importSession -Debug `
                -ArgumentList (($resourceGroupPrefix,($deployments.$step).rg,$env,'rg' ) -join '-'), "$scriptroot\templates\scenarios\$(($deployments.$step).name)\azuredeploy.json", $deploymentData[1], (($deploymentData[0], ($deployments.$step).name) -join '-').ToString().Replace('\','-'), $scriptRoot, $subscriptionId
        }
    }
    catch {
        # Critical failure was detected. Exiting script.
        Write-Error $_
    }
}

<#
.SYNOPSIS
    This function publish required scripts and templates to artifacts storage account for deployment.
#>
function Publish-BuildingBlocksTemplates ($hash) {
    $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName (($resourceGroupPrefix,'workload',$env,'rg') -join '-')  -Name $hash -ErrorAction SilentlyContinue
    if (!$StorageAccount) {
        $StorageAccount = New-AzureRmStorageAccount -ResourceGroupName (($resourceGroupPrefix,'workload',$env,'rg') -join '-') -Name $hash -Type Standard_LRS `
            -Location $location -ErrorAction Stop
    }
    $ContainerList = (Get-AzureStorageContainer -Context $StorageAccount.Context | Select-Object -ExpandProperty Name)
    Get-ChildItem $scriptroot -Directory -Filter templates | ForEach-Object {
        $Directory = $_
        if ( $Directory -notin $ContainerList ) {
            $StorageAccount | New-AzureStorageContainer -Name $Directory.Name -Permission Container -ErrorAction Stop | Out-Null
        }
        Get-ChildItem $Directory.FullName -Recurse -File -Filter *.json | ForEach-Object {
            Set-AzureStorageBlobContent -Context $StorageAccount.Context -Container $Directory.Name -File $_.FullName -Blob $_.FullName.Remove(0,(($Directory).FullName.Length + 1)) -Force -ErrorAction Stop | Out-Null
            log "Uploaded $($_.FullName) to $($StorageAccount.StorageAccountName)." Yellow
        }
    }
    Get-ChildItem $scriptroot -Directory -Filter functions | ForEach-Object {
        $Directory = $_
        if ( $Directory -notin $ContainerList ) {
            $StorageAccount | New-AzureStorageContainer -Name $Directory.Name -Permission Container -ErrorAction Stop | Out-Null
        }
        Get-ChildItem $Directory.FullName -Recurse -File -Filter *.zip | ForEach-Object {
            Set-AzureStorageBlobContent -Context $StorageAccount.Context -Container $Directory.Name -File $_.FullName -Blob $_.FullName.Remove(0,(($Directory).FullName.Length + 1)) -Force -ErrorAction Stop | Out-Null
            log "Uploaded $($_.FullName) to $($StorageAccount.StorageAccountName)." Yellow
        }
    }
}

<#
.SYNOPSIS
    This function imports deployment parameters file, updates the values and creates a new parameter file at temp location.
#>
function Get-DeploymentData($hash) {
    $tmp = [System.IO.Path]::GetTempFileName()
    $deploymentName = "{0}-{1}-{2}" -f $deploymentPrefix, (Get-Date -Format MMddyyyy), $uniqueDeploymentHash
    $localIP = Invoke-RestMethod https://ipinfo.io/json | Select-Object -exp ip
    $parametersData = Get-Content "$scriptroot\templates\azuredeploy.parameters.json" | ConvertFrom-Json
    $parametersData.parameters.environmentReference.value.env = $env
    $parametersData.parameters.environmentReference.value.prefix = $resourceGroupPrefix
    $parametersData.parameters.environmentReference.value._artifactsLocation = 'https://{0}.blob.core.windows.net/' -f $hash
    $parametersData.parameters.environmentReference.value.adAppClientId = $healthCareAdApplicationClientId
    $parametersData.parameters.environmentReference.value.deploymentPassword = $deploymentPassword
    $parametersData.parameters.environmentReference.value.tenantId = $tenantId
    $parametersData.parameters.environmentReference.value.tenantDomain = $tenantDomain
    $parametersData.parameters.environmentReference.value.location = $location
    $parametersData.parameters.workloadReference.value.sql.firewallRules[0].startIP = $localIP
    $parametersData.parameters.workloadReference.value.sql.firewallRules[0].endIP = $localIP
    $parametersData.parameters.workloadReference.value.sql.sqlADAdministratorSid = $sqlAdAdminObjID
    $parametersData.parameters.workloadReference.value.sql.tdeKeyUri = $sqlTdeKeyUrl
    $parametersData.parameters.workloadReference.value.sql.sqlServerKeyName = $sqlServerKeyName
    $parametersData.parameters.workloadReference.value.keyVault.secretExpirationDate = $unixTimeStamp
    $parametersData.parameters.workloadReference.value.keyVault.accessPolicies[0].tenantId = $tenantId
    $parametersData.parameters.workloadReference.value.keyVault.accessPolicies[0].objectId = $siteAdminObjId
    $parametersData.parameters.workloadReference.value.keyVault.accessPolicies[1].tenantId = $tenantId
    $parametersData.parameters.workloadReference.value.keyVault.accessPolicies[1].objectId = $healthCareAdServicePrincipalObjectId
    $parametersData.parameters.workloadReference.value.azureML.predictLengthOfStayServiceEndpoint = $predictLengthOfStayServiceEndpoint
    $parametersData.parameters.workloadReference.value.azureML.predictLengthOfStayServiceApiKey = $predictLengthOfStayServiceApiKey
    $parametersData.parameters.monitoring.value.appInsights.plan = $appInsightsPlan
    ( $parametersData | ConvertTo-Json -Depth 10 ) -replace "\\u0027", "'" | Out-File $tmp
    $deploymentName, $tmp
}

<#
.SYNOPSIS
    This function registers resource providers.
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )
    log "Registering resource provider '$ResourceProviderNamespace'.";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace | Out-Null;
}

<#
.SYNOPSIS
    This function generates a strong 15 length random password using UPPER & lower case alphabets, numbers and special characters.
#>
function New-RandomPassword(){
    (-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})) + `
    ((10..99) | Get-Random -Count 1) + `
    ('@','%','!','^' | Get-Random -Count 1) +`
    (-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})) + `
    ((10..99) | Get-Random -Count 1)
}

<#
.SYNOPSIS
    Function to get the ARM deployment status from the background job, updates logfile and display as an output.
#>
function Get-ARMDeploymentStatus (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $jobName
) 
{
    $jobOutput = Get-Job -Name $jobName | Select-Object -Last 1 | Receive-Job
    if($jobOutput -ne $null){
        $i = 0
        if($jobOutput -is [system.array]){$count = $jobOutput.Count}
        else {$count = 1}
        for ($i = 0; $i -lt $count; $i++) {
            if ($jobOutput[$i].pstypenames[0] -eq 'Deserialized.System.Management.Automation.VerboseRecord')
            {
                $string = $jobOutput[$i]
                if ($string -match ' PM - '){
                    $logMessage = ($string -split ' PM - ')[1]
                }
                elseif ($string -match ' AM -'){
                    $logMessage = ($string -split ' AM - ')[1]
                }
                else{
                    $logMessage = $string
                }
                log "$logMessage"
            }
        }
    }
}
