<#
.SYNOPSIS
    This script:
    1. Unzips provisioning payload.
    2. Resets the administrator password to a new random value.
    3. Impersonates local administrator account, for access to local SQL instance.
    4. Enables TDE using azure key vault integration, and then imports CSV dataset into local SQL instance.
    5. Obtains managed service identity (MSI) VM access token.
    6. Queries SQL PaaS instance dataset, authenticated as MSI, noting returned row count.
    7. Summarizes results, to local file and substatuses output.
#>



Param ( [string] $adminUserName, [string] $payloadFileName, [string] $sqlServerAddress, [string] $sqlCredentialName, [string] $sqlKeyVaultKeyName )
    $StartDate = Get-Date
    $scriptRoot = Get-Location
    $nodeName = $env:computername

    Get-Date > payloadlog.txt
    echo $nodeName >> payloadlog.txt
    echo $adminUserName >> payloadlog.txt
    echo $payloadFileName >> payloadlog.txt
    echo $sqlServerAddress >> payloadlog.txt
    echo $sqlCredentialName >> payloadlog.txt
    echo $sqlKeyVaultKeyName >> payloadlog.txt
    echo $scriptRoot.Path >> payloadlog.txt

    #
    # unzip payload
    #

    $payloadFile = $scriptRoot.Path + '\' + $payloadFileName
    $schemaFile = $scriptRoot.Path + '\patientdb_schema_nolos.sql'
    $csvArtifactFile = $scriptRoot.Path + '\LengthOfStay-IaaSDemo.csv'
    $helperFunctionsFile = $scriptRoot.Path + '\sql-setup-functions.ps1'

    Add-Type -assembly "system.io.compression.filesystem"

    try {
        [io.compression.zipfile]::ExtractToDirectory($payloadFile, $scriptRoot.Path) 
    } catch [System.Exception]
    {
        Write-Error -Message $_.Exception.Message
        Write-Output "Failed sql-setup.ps1 payload $($payloadFileName) for VM $($nodeName) (unzip of payload)"
        echo "Failed to unzip payload." >> payloadlog.txt
        exit 1
    }

    # check for existence of unpacked payload
    If( (!(Test-path $csvArtifactFile)) -Or
        (!(Test-path $schemaFile)) -Or
        (!(Test-path $helperFunctionsFile)))
    {
        Write-Output "Failed to find necessary artifact files for VM $($nodeName)"
        echo "Failed to find necessary artifact files." >> payloadlog.txt
        exit 2
    }


    #
    # import helper functions.
    #

    . $helperFunctionsFile

    #
    # reset password of localadministrator to random value.
    # then process artifacts for the local SQL instance.
    #

    $guid = New-Guid
    $username = $adminUserName
    $domain = $env:computername
    $password = $guid.Guid.ToString()

    try {
        [adsi]$userVariable = "WinNT://$($domain)/$($username)"
        $userVariable.SetPassword($password)
    } catch {
        Write-Error "Failed to set adminstrator account password."
        echo "Failed to set administrator account password." >> payloadlog.txt
        exit 3
    }

    # queries to create patientdb and enable TDE using AKV integration.

    $DomainUsername = "$($domain)\$($username)"
    $KeyVaultKeyName = "'$sqlKeyVaultKeyName'"

    $querysetupTDE =@"
    USE master;

    if db_id('patientdb') is null
    CREATE DATABASE patientdb;	-- create patientdb, as it doesn't exist

    -- this query can be executed repeatedly for a given deployment, so only execute the encryption enable steps once
    IF EXISTS (SELECT * FROM sys.dm_database_encryption_keys WHERE (database_id = db_id('patientdb') AND encryption_state != 0))
    SET NOEXEC ON;	-- the database exists and is already encrypted/pending encryption, nothing more to do.
    
    ALTER LOGIN [$DomainUsername]  
    ADD CREDENTIAL $sqlCredentialName;	-- add AAD credential to admin login, to allow connection to keyvault
    GO

    CREATE ASYMMETRIC KEY TDE_KEY		-- create TDE key, protected by keyvault backed key  
    FROM PROVIDER [AzureKeyVault_EKM_Prov]  
    WITH PROVIDER_KEY_NAME = $KeyVaultKeyName,  
    CREATION_DISPOSITION = OPEN_EXISTING;
    GO

    ALTER LOGIN [$DomainUsername]  
    DROP CREDENTIAL $sqlCredentialName;	-- remove AAD credential from admin login.
    GO

    IF NOT EXISTS (SELECT name FROM master.sys.server_principals WHERE name = 'TDE_Login')
    BEGIN
    CREATE LOGIN TDE_Login   
    FROM ASYMMETRIC KEY TDE_KEY;
    END

    ALTER LOGIN TDE_Login   
    ADD CREDENTIAL $sqlCredentialName;	-- add AAD credential to TDE_Login, to allow connection to keyvault
    GO 

    -- enable encryption on patientdb
    USE patientdb;
    GO

    CREATE DATABASE ENCRYPTION KEY   
    WITH ALGORITHM = AES_256   
    ENCRYPTION BY SERVER ASYMMETRIC KEY TDE_KEY;  
    GO

    ALTER DATABASE patientdb
    SET ENCRYPTION ON;
    GO  
    SET NOEXEC OFF;
"@

    $query = "BULK INSERT [dbo].[PatientData] FROM '$csvArtifactFile' WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n')"
    $LocalSqlSetup = $false

    try {
        ($hToken, $fSuccess) = LogonUser -UserName $username -Domain $domain -Password $password

        if(!($fSuccess)) {
            Write-Error "Failed to Logon adminstrator account."
            echo "Failed to LogonUser administrator account." >> payloadlog.txt
            exit 4
        }

        ($IdentityContext) = ImpersonateLoggedOnUser -hToken $hToken

        # setup patientDB and enable SQL TDE
        Invoke-SqlCmd -ConnectionString 'Server=localhost;Integrated Security=SSPI;Persist Security Info=False;'  -Query $querysetupTDE -OutputSqlErrors $true
        echo "patientdb created, TDE enabled." >> payloadlog.txt

        # setup database schema:
        Invoke-Sqlcmd -ConnectionString 'Server=localhost;Initial Catalog=patientdb;Integrated Security=SSPI;Persist Security Info=False;' -InputFile $schemaFile -QueryTimeout 60 -OutputSqlErrors $true
        echo "patientdb schema configured." >> payloadlog.txt

        # import data
        Invoke-SqlCmd -ConnectionString 'Server=localhost;Initial Catalog=patientdb;Integrated Security=SSPI;Persist Security Info=False;'  -Query $query -OutputSqlErrors $true
        echo "patientdb data imported." >> payloadlog.txt

        $LocalSqlSetup = $true
    } catch [System.Exception]
    {
        Write-Error -Message $_.Exception.Message
        Write-Output "Failed SQL Import payload $($payloadFileName) for VM $($nodeName)."
        echo "Failed SQL Import." >> payloadlog.txt

    } finally {
        $password = $null

        if ($IdentityContext)
        {
            $IdentityContext.Undo()
            $IdentityContext.Dispose()
            $null = CloseHandle -hObject $hToken
        }
    }

    if($LocalSqlSetup -ne $true)
    {
        echo "Failed SQL configuration." >> payloadlog.txt
        exit 5
    }

    echo "IaaS VM SQL import complete" >> payloadlog.txt

    # remove artifacts

    If(Test-path $payloadFile) {Remove-item $payloadFile}
    If(Test-path $csvArtifactFile) {Remove-item $csvArtifactFile}
    If(Test-path $schemaFile) {Remove-item $schemaFile}
    If(Test-path $helperFunctionsFile) {Remove-item $helperFunctionsFile}

    echo "Execution artifacts removed" >> payloadlog.txt

    #
    # obtain MSI access token for interacting with PaaS database instance
    #

    try
    {
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fdatabase.windows.net%2F' -Method GET -Headers @{Metadata="true"}
    }
    catch [System.Exception]
    {
        Write-Error -Message $_.Exception.Message
        Write-Output "Failed sql-setup.ps1 for VM $($nodeName) (getting MSI auth token)"
        echo "Failed to get MSI token." >> payloadlog.txt
        exit 6
    }

    $content = $response.Content | ConvertFrom-Json
    $AccessToken = $content.access_token

    echo "Obtained MSI accesstoken" >> payloadlog.txt

    #
    # connect to PaaS database
    #

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=tcp:$($sqlServerAddress),1433;Initial Catalog=patientdb;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Integrated Security=False;Connection Timeout=15;"
    $SqlConnection.AccessToken = $AccessToken

    try {	
        $SqlConnection.Open()
    } catch [System.Exception]
    {
        Write-Error -Message $_.Exception.Message
        Write-Output "SqlConnection.Open() fail!"
        echo "Failed SqlConnection.Open on remote PaaS instance." >> payloadlog.txt
        exit 7
    }

    echo "Connected to PaaS sql instance, query results follow" >> payloadlog.txt

    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand

    # issue query against dbo.MetaData_Facilities
    $SqlCmd.CommandText = "SELECT * from dbo.MetaData_Facilities;"
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $rowCount = $SqlAdapter.Fill($DataSet)
    $SqlConnection.Close()

    if($rowCount -eq $null)
    {
        $rowCount = 'null: possible non-existent DB content'
    }

#    echo $DataSet.Tables[0] >> payloadlog.txt
    echo "$($rowCount) rows returned from PaaS db query" >> payloadlog.txt

    #
    # calculate elapsed time and log outcome.
    #

    $StopDate = Get-Date
    $Elapsed = $StopDate - $StartDate

    echo "Completed in $($Elapsed.Seconds) seconds" >> payloadlog.txt

    Write-Output "$($StopDate): Executed sql-setup.ps1 successfully. $($rowCount) rows returned, elapsedTime $($Elapsed.Seconds) seconds."
