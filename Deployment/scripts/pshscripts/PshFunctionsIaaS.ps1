<#
.SYNOPSIS
    This function prepares the SQL setup script and storage account artifacts
#>
Function TransferExecute-PayloadFunction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [string]$resourceGroupName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
            [string]$artifactsStorageAccountName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
            [string]$artifactsStorageContainerName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
            [string]$VNetName
    )

    $scriptRoot = Get-Location

    $ArtifactStagingDirectory = 'stage'
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $ArtifactStagingDirectory))

    $ArtifactsStorageAccount = Get-AzureRmStorageAccount -ResourceGroup $resourceGroupName -Name $artifactsStorageAccountName -ErrorAction SilentlyContinue

    # Create the storage account
    if ($ArtifactsStorageAccount -eq $null) {
        log "Creating storage account $($artifactsStorageAccountName) to hold script execution artifacts"

        $ArtifactsStorageAccount = New-AzureRmStorageAccount -StorageAccountName $artifactsStorageAccountName -Type 'Standard_LRS' `
                            -ResourceGroupName $resourceGroupName -Location $location `
                            -EnableHttpsTrafficOnly $true -EnableEncryptionService blob

    } else {
        #
        # storage account name is unque each invocation. If a name conflict, do not proceed, as the referenced storage account will be deleted.
        #
        logerror
        Break
    }

    if ($ArtifactsStorageAccount -eq $null) {
        logerror
        Break
    }

    $container = New-AzureStorageContainer -Name $artifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -ErrorAction SilentlyContinue

    if($container -eq $null)
    {
        logerror
        Break
    }

    #
    # prepare zip archive.
    #

    $guid = New-Guid
    $guid = $guid.Guid.ToString()

    $sourceFiles = $ArtifactStagingDirectory+'\artifact'
    $destinationZip = $ArtifactStagingDirectory+'\sql-setup-'+$guid+'.zip'

    If(Test-path $destinationZip) {Remove-item $destinationZip}

    log "Adding record set artifact to zipfile $($destinationZip)"

    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::CreateFromDirectory($sourceFiles, $destinationZip, "Optimal", $false) 

    #
    # transfer the powershell script and payload zip file
    #

    log "Adding script execution artifacts to storage account $($artifactsStorageAccountName)"

    $SourcePath = $ArtifactStagingDirectory+'\sql-setup.ps1'
    Set-AzureStorageBlobContent -File $SourcePath -Blob 'sql-setup.ps1' `
            -Container $artifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -Force

    $SourcePath = $destinationZip
    Set-AzureStorageBlobContent -File $SourcePath -Blob 'sql-setup.zip' `
            -Container $artifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -Force

    If(Test-path $destinationZip) {Remove-item $destinationZip}

    #
    # apply firewall rules to storage account, so only subnet has access.
    #
    
    log "Applying firewall policy on storage account $($artifactsStorageAccountName)"

    $subnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $VNetName | Get-AzureRmVirtualNetworkSubnetConfig
    $null = Set-AzureRmStorageAccount -NetworkRuleSet (@{bypass="None";virtualNetworkRules=(@{VirtualNetworkResourceId="$($subnet[0].Id)";Action="allow"});defaultAction="Deny"}) -ResourceGroupName $resourceGroupName -Name $artifactsStorageAccountName

    $resultArray = @()
    $resultArray+= $ArtifactsStorageAccount

    return $resultArray
}


<#
.SYNOPSIS
    This function updates the network security group and access policy to grant VM MSI access to SQL
#>
Function Update-AccessPolicySqlFunction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [string]$resourceGroupName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
            [string]$environment,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
            [string]$sqlDbServerName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
            [string]$sqlDbServerResourceGroup,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4)]
            [string]$VMName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 5)]
            [string]$VNetName
    )

    $status = $false
    $setAdministrator = $false

    $SubnetName = 'SQLSubnet'
    $VNetRuleName = 'SQL_IaaS_Access'

    $ExistingRule = Get-AzureRmSqlServerVirtualNetworkRule -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -VirtualNetworkRuleName $VNetRuleName -ErrorAction SilentlyContinue

    if($ExistingRule -eq $null)
    {
        log "Setting SQL PaaS Firewall rule."

        #
        # setup subnet and network rule on SQL PaaS instance
        #

        $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
        if($vnet -eq $null) {
            logerror
            return $false
        }

        $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
    
        if($subnet -eq $null) {
            logerror
            return $false
        }
    
        $vnetRuleObject = New-AzureRmSqlServerVirtualNetworkRule -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -VirtualNetworkRuleName $VNetRuleName -VirtualNetworkSubnetId $subnet[0].Id -ErrorAction SilentlyContinue
        if($vnetRuleObject -eq $null) {
            log "Error setting SQL PAAS firewall rule subnetid $($subnet[0].Id)"
            return $false
        }
    } else {
        log "SQL PaaS Firewall rule already set."
    }

    #
    # obtain the MSI identity info for the VM
    #

    $VM = Get-AzureRmVm -ResourceGroup $resourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    if($VM -eq $null)
    {
        logerror
        return $false
    }

    log "VM MSI ApplicationId $($VM.Identity.PrincipalId)"

    #
    # connect to AzureAD, create an AAD group, add the MSI to the group, and grant access to the PaaS SQL server
    #

    $currentAzureContext = Get-AzureRmContext
    $tenantId = $currentAzureContext.Tenant.Id
    $accountId = $currentAzureContext.Account.Id

    try {
        $ad = Connect-AzureAD -TenantId $tenantId -AccountId $accountId
    } catch {
        Write-Error -Message $_.Exception.Message
        return $false
    }

    $GroupName = $resourceGroupName+' VM MSI access to SQL PaaS instance'
    $Group = Get-AzureADGroup -SearchString $GroupName -ErrorAction SilentlyContinue

    if($Group -eq $null)
    {
        log "creating VM MSI Access group"
        $Group = New-AzureADGroup -DisplayName $GroupName -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
    } else {
        log "VM MSI Access group already exists"
    }

    log "Containing group for VM MSI objectID=$($Group.ObjectId)"

    $ret = Get-AzureADGroupMember -All $true -ObjectId $Group.ObjectId -ErrorAction SilentlyContinue | Where-Object {$_.ObjectId -match $VM.Identity.PrincipalId}

    if($ret -eq $null)
    {
        try {
            $ret = Add-AzureAdGroupMember -ObjectId $Group.ObjectId -RefObjectId $VM.Identity.PrincipalId -ErrorAction SilentlyContinue
        } catch {
            Write-Error -Message $_.Exception.Message
            return $false
        }
    } else {
        log "VM MSI already a member of group."
    }

    # disconnect azureAD
    $null = Disconnect-AzureAD

    #
    # enable AD based administrator
    #

    # get user ObjectId associated with current azure context.

    $cache = $currentAzureContext.TokenCache
    $token = $cache.ReadItems() | Where-Object { $_.TenantId -eq $currentAzureContext.Tenant.TenantId -And $_.DisplayableId -eq $currentAzureContext.Account.Id }

    if($token -eq $null) {
        log "Unable to determine current user objectId information."
        logerror
        Break
    }

    $accountObjectId = $token[0].UniqueId

    $CurrentAdmin = Get-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -ErrorAction SilentlyContinue

    if(($CurrentAdmin -eq $null) -Or
       ($CurrentAdmin.ObjectId -ne $accountObjectId))
    {
        log "Enabling SQL AD administrator user = $($accountId)."
        $null = Set-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -ObjectId $accountObjectId -DisplayName $accountId

        $setAdministrator = $true
    } else {
        log "User already SQL AD administrator."
    }


    #
    # setup access to group containing MSI, and grant db_datareader access.
    #

    # obtain AAD token for https://database.windows.net/
    #

    $TenantId = $currentAzureContext.Tenant.TenantId
    $resource = "https://database.windows.net/" 
    $authUrl = "https://login.windows.net/$TenantId/" 
    $ClientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authUrl, $false) 

    # UserIdentifier enum
    # 0 = UniqueId
    # 2 = RequiredDisplayableId
    $userid = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier($accountObjectId, 0)
    $authResult = $authContext.AcquireTokenSilentAsync($resource, $ClientId, $userid)

    if($authResult.Result -eq $null)
    {
        $redirect = 'urn:ietf:wg:oauth:2.0:oob'
        $authResult = $authContext.AcquireToken($resource, $ClientId, $redirect, 0, $userid)
        if($authResult -eq $null)
        {
            log "Unable to obtain AAD user auth token for current azure context."
            logerror
            Break
        }
    } else {
        $authResult = $authResult.Result
    }

    $SqlServerAddress = $SqlDbServerName +'.database.windows.net'

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=tcp:$($SqlServerAddress),1433;Initial Catalog=patientdb;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Integrated Security=False;Connection Timeout=15;"
    $SqlConnection.AccessToken = $authResult.AccessToken

    $SqlConnection.Open()

    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet

    #
    # only make changes if necessary during both SQL queries
    #

    $queryCreateUser = "IF DATABASE_PRINCIPAL_ID('$GroupName') IS NULL BEGIN CREATE USER [$GroupName] FROM EXTERNAL PROVIDER END"

    $SqlCmd.CommandText = $queryCreateUser

    log "Executing SQL PaaS CREATE USER for VM MSI"

    try {
        $rowCount = $SqlAdapter.Fill($DataSet)
        log "Sucessfully issued CREATE USER for VM MSI."
    } catch {
        log "Caught exception during CREATE USER"
        Write-Error -Message $_.Exception.Message
    }

    $queryAlterRole = "IF IS_ROLEMEMBER ( 'db_datareader','$GroupName' ) = 0 BEGIN ALTER ROLE db_datareader ADD MEMBER [$GroupName] END"

    $SqlCmd.CommandText = $queryAlterRole

    log "Executing SQL PaaS ALTER ROLE for VM MSI"
    try {
        $rowCount = $SqlAdapter.Fill($DataSet)
        log "Sucessfully updated PaaS firewall and MSI access policy."
        $status = $true
    } catch {
        log "caught exception during ALTER ROLE"
        Write-Error -Message $_.Exception.Message
    }

    $SqlConnection.Close()

    if( ($setAdministrator -eq $true) )
    {
        if($CurrentAdmin -eq $null) {
            log "Removing PaaS SqlServer Ad Admin - returning to original value."
            $null = Remove-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName
        } else {
            if($CurrentAdmin.ObjectId -ne $accountObjectId) {
                log "Resetting PaaS SqlServer Ad Admin to original value."
                $null = Set-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -DisplayName $CurrentAdmin.DisplayName -ObjectId $CurrentAdmin.ObjectId
            }
        }
    }

    $status
}


<#
.SYNOPSIS
    This function creates a keyvault key and updates the SQL IaaS extension keyvault settings.
#>
Function Update-SqlIaaSExtensionKeyVault {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [string]$resourceGroupName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
            [string]$VMName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
            [securestring]$autoBackupPassword,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
            [string]$KeyVaultServicePrincipalName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4)]
            [securestring]$KeyVaultServicePrincipalSecret,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 5)]
            [string]$KeyVaultCredentialName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 6)]
            [string]$KeyVaultKeyName
    )

    $vaultName = $resourceGroupName+'-sql-kv'

    $CredentialAlreadyExists = $false

    $ExtensionSettings = Get-AzureRmVMSqlServerExtension -ResourceGroupName $resourceGroupName -VMName $VMName
    
    if($ExtensionSettings.KeyVaultCredentialSettings.Enable -eq $true)
    {
        $Credentials = $ExtensionSettings.KeyVaultCredentialSettings.Credentials

        $Credentials | ForEach-Object {
            if( ($_.CredentialName -eq $KeyVaultCredentialName) -And
                ($_.KeyVaultName -eq $vaultName) )
            {
                $CredentialAlreadyExists = $true
            }
        }
    }

    if($CredentialAlreadyExists -eq $true)
    {
        log "SQL vault credential configured and already matches, skipping IaaS extension update."
        return $true
    }

    log "Adding new key $($KeyVaultKeyName) to $($vaultName) keyvault."

    $null = Add-AzureKeyVaultKey -VaultName $vaultName -Name $KeyVaultKeyName -Destination 'HSM' -KeyOps wrapKey,unwrapKey

    $KeyVaultUrl = "https://$($vaultName).vault.azure.net/"

    $KeyVaultCredentialSettings = New-AzureRmVMSqlServerKeyVaultCredentialConfig -ResourceGroupName $resourceGroupName `
                                     -Enable `
                                     -CredentialName $KeyVaultCredentialName `
                                     -AzureKeyVaultUrl $KeyVaultUrl `
                                     -ServicePrincipalName $KeyVaultServicePrincipalName `
                                     -ServicePrincipalSecret $KeyVaultServicePrincipalSecret
    

    log "Updating SqlIaaSExtension to enable keyvault integration."
    $ExtensionStatus = Set-AzureRmVMSqlServerExtension -ResourceGroupName $resourceGroupName -VMName $VMName `
        -KeyVaultCredentialSettings $KeyVaultCredentialSettings

    if($ExtensionStatus.IsSuccessStatusCode -ne $true)
    {
        log "Failed to update SQL IaaS extension KeyVault configuration."
        return $false
    }

    log "Successfully updated SQL IaaS extension KeyVault configuration."

    #
    # note: the deployment script should be updated to use recent RM powershell extensions.
    # At that point, the virtualnetwork configuration can be locked down to the same VNET as used for storage accounts.
    #
    # Add-AzureRmKeyVaultNetworkRule -VirtualNetworkResourceId
    # Update-AzureRmKeyVaultNetworkRuleSet -DefaultAction Deny
    #

    return $true
}
