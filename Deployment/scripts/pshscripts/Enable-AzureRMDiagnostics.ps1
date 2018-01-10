<#PSScriptInfo

.VERSION 2.52

.GUID 7fe4961a-160d-4050-bba8-b80e649e0d48

.AUTHOR jbritt@microsoft.com

.COMPANYNAME Microsoft

.COPYRIGHT Microsoft

.TAGS 

.LICENSEURI 

.PROJECTURI 
https://blogs.technet.microsoft.com/msoms/2017/01/17/enable-azure-resource-metrics-logging-using-powershell

.ICONURI 
https://msdnshared.blob.core.windows.net/media/2017/01/1-OMS-011717.png

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
September 14, 2017 Fixes
   Fixed Logic in initial authentication check for Azure Login.

   Thank you Paul!

   https://blogs.technet.microsoft.com/msoms/2017/01/17/enable-azure-resource-metrics-logging-using-powershell/#comment-62455 

   Updated minor try / catch logic
#>

<#  
.SYNOPSIS  
  Configure a resource (given a resource ID in Azure) to enable Azure Diagnostics and send that data to an OMS Workspace. 
  This WSID specified as a parameter is the resourceID of the OMS workspace within an Azure Subscription in the following format
  
  "/subscriptions/<subscriptionID GUID>/resourceGroups/<OMS Resource Group>/providers/Microsoft.OperationalInsights/workspaces/<OMS WS Name>"

  Note  This script currently supports onboarding Azure resources that support Azure Diagnostics (metrics and logs) to Log Analytics.
  
  Use of Update switch "-Update $True" updates the resource to a new workspace ID and enable diagnostics
  or just refresh the configuration for all resources.

  Use of "-Force" provides the ability to launch this script without prompting, if all required parameters are provided.
  
.DESCRIPTION  
  This script takes a SubscriptionID, ResourceType, ResourceGroup and a workspace ID as parameters, analyzes the subscription or
  specific ResourceGroup defined for the resources specified in $Resources, and enables those resources for diagnostic metrics
  also enabling the workspace ID for the OMS workspace to receive these metrics.

.PARAMETER Update
    Specify update if you want to update all resources regardless of configuration

.PARAMETER WSID    
    The resourceID of your OMS workspace within Azure

.PARAMETER SubscriptionId
    The subscriptionID of the Azure Subscription that contains the resources you want to update

.PARAMETER ResourceType
    The ResourceType you want to update within your Azure Subscription
    
.PARAMETER ResourceGroupName
    If desired, use a resourcegroup instead of updating all resources of a particular type within an Azure subscription

.PARAMETER ResourceName
    If desired, use a resource name instead of updating all resources of a particular type within an Azure subscription

.PARAMETER Force
    Use Force to run silently [providing all parameters needed for silent mode - see get-help <scriptfile> -examples]

.PARAMETER CategoriesChosen
    Use CategoriesChosen to provide categories for logs to enable in the following format: "JobLogs,JobStreams"

.PARAMETER DisableLogs
    Use this to disable all logs for a resource without requiring categories

.PARAMETER Disablemetrics
    Use this to disable metrics specifically for a resource
    DisableLogs and DisableMetrics can be used at the same time to enable both for a resource that supports both
    Disable switches take precedence over Enable switches

.PARAMETER EnableLogs
    Use this to enable all logs for a resource without requiring categories

.PARAMETER EnableMetrics
    Use this to enable metrics specifically for a resource
    EnableLogs and EnableMetrics can be used at the same time to enable both for a resource that supports both

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -WSID "/subscriptions/fd2323a9-2324-4d2a-90f6-7e6c2fe03512/resourceGroups/OI-EAST-USE/providers/Microsoft.OperationalInsights/workspaces/OMSWS" -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceType "Microsoft.Sql/servers/databases" -ResourceGroup "RGName" -Force
  Take in parameters and execute silently without prompting using Force.
  
.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -WSID "/subscriptions/fd2323a9-2324-4d2a-90f6-7e6c2fe03512/resourceGroups/OI-EAST-USE/providers/Microsoft.OperationalInsights/workspaces/OMSWS" -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceType "Microsoft.Sql/servers/databases" -ResourceGroup "RGName" -Force -Update
  Take in parameters and execute silently without prompting and update all resources with a new WSID

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -Verbose
  To Support Verbose log Output

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceType "Microsoft.Network/networkSecurityGroups" -ResourceGroup "RGName" -CategoriesChosen "NetworkSecurityGroupEvent,NetworkSecurityGroupRuleCounter"
  [Enable] all Network Security Groups and respective categories listed for those resources within a targeted subscription and ResourceGroup

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceType "Microsoft.EventHub/namespaces" -CategoriesChosen "ArchiveLogs,OperationalLogs,AutoScaleLogs" -DisableLogs -DisableMetrics
  [Disable] all log categories listed for those resources within a targeted subscription and metrics at the same time

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceType "Microsoft.EventHub/namespaces" -CategoriesChosen "ArchiveLogs,OperationalLogs,AutoScaleLogs" -DisableLogs -DisableMetrics -force
  Silently [disable] all log categories listed for those resources within a targeted subscription and metrics at the same time

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceType "Microsoft.EventHub/namespaces" -DisableMetrics
  [Disable] all metrics for all specified resourceTypes within a targeted subscription

.EXAMPLE
  .\Enable-AzureRMDiagnostics.ps1 -SubscriptionId "fd2323a9-2324-4d2a-90f6-7e6c2fe03512" -ResourceName "MyResource" -EnableMetrics -ResourceType "Microsoft.EventHub/namespaces"
  [Enable] all metrics for all specified resource named of a resourceType within a targeted subscription
  Note if resourcetype is left off - resource must support requested operation or error will be thrown

.NOTES
   AUTHOR: Microsoft Log Analytics Team / Jim Britt Senior Program Manager - Azure CAT 
   LASTEDIT: Sept 14, 2017

   September 14, 2017 Fixes
   Fixed Logic in initial authentication check for Azure Login.

   Thank you Paul!

   https://blogs.technet.microsoft.com/msoms/2017/01/17/enable-azure-resource-metrics-logging-using-powershell/#comment-62455 
   
   Updated minor try / catch logic

   June 03, 2017 Fixes
   Breaking changes with ARM CMDLETS introduced with the below update required an update to the script
   https://github.com/Azure/azure-powershell/blob/preview/documentation/release-notes/migration-guide.4.0.0.md  
   
   Additional logic has been added to check for SubscriptionName versus Name and SubscriptionID versus ID.
   Login check has been updated to use Get-AzureRMSubscription due to changes in Get-AzureRMContext with this
   release of the cmdlets as well.
    
   April 11, 2017 Features
   Introduced (3) new switches - see updated examples
        EnableMetrics - use this to enable metrics specifically for a resource
        EnableLogs - use this to enable all logs for a resource without requiring categories
        EnableLogs and EnableMetrics can be used at the same time to enable both for a resource that supports both
        ResourceName - use this switch to specify a single resource (requires resourceType)

   April 03, 2017 Bug Fixed
   Fixed array logic for DiagnosticCapable when only one resourcetype exists.
   THank you Jeroen van Hartingsveldt for your submitted bug and supporting a resolution!

   March 31, 2017 Bug Fixed
   Added detection for no workspaces in subscription
   Added detection for no monitorable resources to enable in a subscription

   March 30th, 2017 Bug Fixed
   Updated parameter sets for disable switches.

   March 27th, 2017 Features Added
   Style updates:credit goes to Simon Wåhlin <simon.wahlin@knowledgefactory.se> Microsoft MVP – Cloud and Datacenter Management
   Thank you Simon!! for the great improvements in reduced logic complexity and efficiency.

   Feature Updates
   * Adding Azure Diagnostic Logs as an option for sending to Log Analytics.
   * Disable Logs and Metrics [see examples] 

   Peer Reviews and Input: Kristian Nese, Tiander Turpijn [Azure CAT] / Richard Rundle [OMS PG]

   January 18th, 2017 Bug Fixed
   Bug Resolved with single resource returned for resourcetype not initializing an array object.
   How Found: Simon Wåhlin <simon.wahlin@knowledgefactory.se> Microsoft MVP – Cloud and Datacenter Management

.LINK
    This script posted to and discussed at the following locations:
        https://www.powershellgallery.com/packages/Enable-AzureRMDiagnostics
        https://blogs.technet.microsoft.com/msoms/2017/01/17/enable-azure-resource-metrics-logging-using-powershell/
        https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-azure-sql/
#>
param
(
    # Use Update to refresh a configuration such as changing to a new OMS WORKSPACE
    [switch]$Update,

    # Provide ResourceID of Workspace within same Tenant 
    # to send multiple subs to one workspace
    [Parameter(Mandatory=$False,ParameterSetName='default')]
    [Parameter(Mandatory=$True,ParameterSetName='force')]
    [string]$WSID,

    # Provide SubscriptionID to bypass subscription listing
    [Parameter(Mandatory=$False,ParameterSetName='default')]
    [Parameter(Mandatory=$True,ParameterSetName='force')]
    [guid]$SubscriptionId,

    # Add ResourceType to reduce scope to Resource Type instead of entire list of resources to scan
    [Parameter(Mandatory=$False,ParameterSetName='default')]
    [Parameter(Mandatory=$True,ParameterSetName='force')]
    [string]$ResourceType,

    # Add a ResourceGroup name to reduce scope from entire Azure Subscription to RG
    [string]$ResourceGroupName,

    # Add a ResourceName name to reduce scope from entire Azure Subscription to specific named resource
    [string]$ResourceName,

    # Provide categories for logs to enable in the following format: "JobLogs,JobStreams"
    [string]$CategoriesChosen,

    # Use Force to run in silent mode (requires certain parameters to be provided)
    [Parameter(Mandatory=$True,ParameterSetName='force')]
    [switch]$Force,

    # Use to remove the configuration of logs for a selected resource type
    [switch]$DisableLogs,
    
    # Use to remove the configuration of metrics for a selected resource type
    [switch]$DisableMetrics,

    # Use to add the configuration of logs for a selected resource type (not requiring categories)
    # CategoriesChosen switch can be used in combination to enable granular category choice
    # Can be used with $EnableMetrics to enable metrics and logs at the same time
    [switch]$EnableLogs,
    
    # Use to add the configuration of metrics for a selected resource type
    # Can be used with $EnableLogs to enable metrics and logs at the same time
    [switch]$EnableMetrics
   
)
# FUNCTIONS
# Get the ResourceType listing from all ResourceTypes capable in this subscription
# to be sent to log analytics - use "-ResourceType" param to bypass
function Get-ResourceType (
    [Parameter(Mandatory=$True)]
    [array]$allResources
    )
{
    $analysis = @()
    
    foreach($resource in $allResources)
    {
        $Categories =@();
        $metrics = $false #initialize metrics flag to $false
        $logs = $false #initialize logs flag to $false
    
        if (! $analysis.where({$_.ResourceType -eq $resource.ResourceType}))
        {
            try
            {
                Write-Verbose "Checking $($resource.ResourceType)"
                $setting = Get-AzureRmDiagnosticSetting -ResourceId $resource.ResourceId -ErrorAction Stop
                # If logs are supported or metrics on each resource, set value as $True
                if ($setting.Logs) 
                { 
                    $logs = $true
                    $Categories = $setting.Logs.category 
                }


                if ($setting.Metrics) 
                { 
                    $metrics = $true
                }   
            }
            catch {}
            finally
            {
                $object = New-Object -TypeName PSObject -Property @{'ResourceType' = $resource.ResourceType; 'Metrics' = $metrics; 'Logs' = $logs; 'Categories' = $Categories}
                $analysis += $object
            }
        }
    }
    # Return the list of supported resources
    $analysis
}

# Enable Diagnostics and set WSID for each resource (if not already set)
function Set-Resource
{
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$True)]
        [array]$Resources,
        [switch]$Update,
        [string]$WSID,
        [array]$CategoryArray,
        [switch]$DisableLogs,
        [switch]$DisableMetrics,
        [switch]$EnableMetrics,
        [switch]$EnableLogs,
        [psobject]$DiagnosticCapability
    )
    Write-Host "Processing resources.  Please wait...."
    Foreach($Resource in $Resources)
    {
        If(!($DisableLogs) -and !($DisableMetrics))
        {   
            $WSIDOK = $True
            $ResourceDiagnosticSetting = get-AzureRmDiagnosticSetting -ResourceId $Resource.ResourceId 
            if($ResourceDiagnosticSetting.WorkspaceId -ne $null -and $ResourceDiagnosticSetting.WorkspaceId -ne $WSID -and $Update -eq $False)
            {
                # If update switch not used, WSIDOK is set to false and warning is thrown
                $WSIDOK = $False
                $WS = ($ResourceDiagnosticSetting.WorkspaceId -split "/workspaces/", 2)[1]
                Write-Host "Resource $($Resource.Name) is already enabled for Workspace $WS. " -NoNewline
                write-host "Use -Update" -ForegroundColor Yellow

            }
            # Update switch enables updating workspaceID if one is already specified.
            if($Update -eq $True -and $WSIDOK -eq $True)
            {
                try
                {
                    $WS = ($WSID -split "/workspaces/", 2)[1]
                    $Diag = Set-AzureRmDiagnosticSetting -WorkspaceId $WSID -ResourceId $Resource.ResourceId
                    if($Diag){Write-Host "Workspace for existing resource $($Resource.Name) was updated to $WS."}
                }
                catch
                {
                    write-host "An error occurred setting diagnostics on $($Resource.Name)"
                }
            }
        
            # Metrics
            if(!($CategoryArray) -or $EnableMetrics -and $DiagnosticCapability.metrics -eq $True)
            {
                if($ResourceDiagnosticSetting.Metrics.Enabled -eq $False -and $DiagnosticCapability.metrics)
                {
                    try
                    {
                        $Diag = Set-AzureRmDiagnosticSetting -WorkspaceId $WSID -ResourceId $Resource.ResourceId -Enabled $True -Timegrains "PT1M"
                        if($Diag){Write-Host "Metrics gathering for new resource $($Resource.Name) was set to enabled"}
                    }
                    catch
                    {
                        write-host "An error occurred setting diagnostics on $($Resource.Name)"
                    }
                }
            }
            # Logs and categories
            if($CategoryArray -or $EnableLogs -and $DiagnosticCapability.logs -eq $True)
            {
                if($CategoryArray)
                {
                    Foreach($Category in $CategoryArray)
                    {
                        foreach($ResDiagSetting in $ResourceDiagnosticSetting.logs)
                        {
                            if($ResDiagSetting.category -eq $Category -and $ResDiagSetting.enabled -eq $False)
                            {
                                try
                                {
                                    $Diag = Set-AzureRmDiagnosticSetting -WorkspaceId $WSID -ResourceId $Resource.ResourceId -Enabled $True -Categories $Category
                                    if($Diag){Write-Host "Resource $($Resource.Name) was enabled for Log Category $Category"}
                                }
                                catch
                                {
                                    Throw "An error occurred setting diagnostics on $($Resource.Name) for $Category"
                                }
                            }
                        }
                    }
                }
                elseif($EnableLogs)
                {
                    foreach($ResDiagSetting in $ResourceDiagnosticSetting.logs)
                    {
                        # Enable only logs if not already enabled
                        # (enablelogs bypasses categorieschosen param)
                        if($ResDiagSetting.enabled -eq $False)
                        {
                            try
                            {
                                $Diag = Set-AzureRmDiagnosticSetting -WorkspaceId $WSID -ResourceId $Resource.ResourceId -Enabled $True -Categories $($ResDiagSetting.category)
                                if($Diag){Write-Host "Resource $($Resource.Name) was enabled for Log Category $($ResDiagSetting.category)"}
                            }
                            catch
                            {
                                write-host "An error occurred setting diagnostics on $($Resource.Name) for $($ResDiagSetting.category)"
                            }
                        }
                    }
                }

            }
        }
        # Logic for Disabling logs and metrics
        elseif($DisableLogs -or $DisableMetrics)
        {
            # Disable specific categories on logs as defined by CategoriesChosen
            if($DisableLogs -and $CategoryArray -and $DiagnosticCapability.logs -eq $True)
            {
                foreach($Category in $CategoryArray)
                {
                    try
                    {
                        $RemoveDiag = Set-AzureRmDiagnosticSetting -ResourceId $Resource.ResourceId -Enabled $False -categories $Category
                        Write-Host "Resource $($Resource.Name) disabled category $Category for gathering"
                    }
                    catch
                    {
                        write-host "An error occurred removing diagnostic log category $Category on $($Resource.Name)"
                    }
                }
            }
            # Disable logs on a resource(s) if logs is a capablity supported on the resource(s)
            # This logic will dynamically build the categories supported and disable all
            # CategoriesChosen will override this if you want to disable only specific categories in a log
            If($DisableLogs -and !($CategoryArray) -and $DiagnosticCapability.logs -eq $True)
            {
                $ResourceDiagnosticSetting = get-AzureRmDiagnosticSetting -ResourceId $Resource.ResourceId
                foreach($Entry in $ResourceDiagnosticSetting.logs)
                {
                    try
                    {
                        $RemoveDiag = Set-AzureRmDiagnosticSetting -ResourceId $Resource.ResourceId -Enabled $False -categories $($Entry.Category)
                        Write-Host "Resource $($Resource.Name) disabled category $($Entry.Category) for gathering"
                    }
                    catch
                    {
                        write-host "An error occurred removing diagnostic log category $Category on $($Resource.Name)"
                    }
                }
            }
            # Disable metrics on a resource(s) if metrics is a capablity supported on the resource(s)
            if($DisableMetrics -and $DiagnosticCapability.Metrics -eq $True)
            {
                try
                {
                    $RemoveDiag = Set-AzureRmDiagnosticSetting -ResourceId $Resource.ResourceId -Enabled $False -Timegrains "PT1M"
                    Write-Host "Resource $($Resource.Name) was disabled for metrics gathering"
                }
                catch
                {
                    write-host "An error occurred removing diagnostic metrics on $($Resource.Name)"
                }
            }
        }
    }
}

# Function used to build numbers in selection tables for menus
function Add-IndexNumberToArray (
    [Parameter(Mandatory=$True)]
    [array]$array
    )
{
    for($i=0; $i -lt $array.Count; $i++) 
    { 
        Add-Member -InputObject $array[$i] -Name "#" -Value ($i+1) -MemberType NoteProperty 
    }
    $array
}

# MAIN SCRIPT
#Variable Definitions
[array]$Resources = @()

# Login to Azure - if already logged in, use existing credentials.
Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try
{
    $AzureLogin = Get-AzureRmSubscription
}
catch
{
    $null = Login-AzureRmAccount
    $AzureLogin = Get-AzureRmSubscription
}

# Authenticate to Azure if not already authenticated 
# Ensure this is the subscription where your Azure Resources are you want to send diagnostic data from
If($AzureLogin -and !($SubscriptionID))
{
    [array]$SubscriptionArray = Add-IndexNumberToArray (Get-AzureRmSubscription) 
    [int]$SelectedSub = 0

    # use the current subscription if there is only one subscription available
    if ($SubscriptionArray.Count -eq 1) 
    {
        $SelectedSub = 1
    }
    # Get SubscriptionID if one isn't provided
    while($SelectedSub -gt $SubscriptionArray.Count -or $SelectedSub -lt 1)
    {
        Write-host "Please select a subscription from the list below"
        $SubscriptionArray | select "#", Id, Name | ft
        try
        {
            $SelectedSub = Read-Host "Please enter a selection from 1 to $($SubscriptionArray.count)"
        }
        catch
        {
            Write-Warning -Message 'Invalid option, please try again.'
        }
    }
    if($($SubscriptionArray[$SelectedSub - 1].Name))
    {
        $SubscriptionName = $($SubscriptionArray[$SelectedSub - 1].Name)
    }
    elseif($($SubscriptionArray[$SelectedSub - 1].SubscriptionName))
    {
        $SubscriptionName = $($SubscriptionArray[$SelectedSub - 1].SubscriptionName)
    }
    write-verbose "You Selected Azure Subscription: $SubscriptionName"
    
    if($($SubscriptionArray[$SelectedSub - 1].SubscriptionID))
    {
        [guid]$SubscriptionID = $($SubscriptionArray[$SelectedSub - 1].SubscriptionID)
    }
    if($($SubscriptionArray[$SelectedSub - 1].ID))
    {
        [guid]$SubscriptionID = $($SubscriptionArray[$SelectedSub - 1].ID)
    }
}
Write-Host "Selecting Azure Subscription: $($SubscriptionID.Guid) ..." -ForegroundColor Cyan
$Null = Select-AzureRmSubscription -SubscriptionId $SubscriptionID.Guid

# Build a list of workspaces to choose from.  If workspace is in another subscription
# provide the resourceID of that workspace as a parameter
# *** OMS workspace currently must be within the same tenant as the resource being configured ***
[array]$Workspaces=@()
if(!($WSID) -and !($DisableLogs) -and !($DisableMetrics))
{
    try
    {
        $Workspaces = Add-IndexNumberToArray (Get-AzureRmOperationalInsightsWorkspace) 
        Write-Host "Generating a list of workspaces from Azure Subscription Selected..." -ForegroundColor Cyan

        [int]$SelectedWS = 0
        if ($Workspaces.Count -eq 1)
        {
            $SelectedWS = 1
        }

        # Get WS Resource ID if one isn't provided
        while($SelectedWS -gt $Workspaces.Count -or $SelectedWS -lt 1 -and $Workspaces -ne $Null)
        {
            Write-Host "Please select a workspace from the list below"
            $Workspaces| select "#", Name, Location, ResourceGroupName, ResourceId | ft
            if($Workspaces.count -ne 0)
            {

                try
                {
                    $SelectedWS = Read-Host "Please enter a selection from 1 to $($Workspaces.count)"
                }
                catch
                {
                    Write-Warning -Message 'Invalid option, please try again.'
                }
            }
        }
    }
    catch
    {
        Write-Warning -Message 'No Workspace found - try specifying parameter WSID'
    }
    If($Workspaces)
    {
        Write-Host "You Selected Workspace: " -nonewline -ForegroundColor Cyan
        Write-Host "$($Workspaces[$SelectedWS - 1].Name)" -ForegroundColor Yellow
        $WSID = $($Workspaces[$SelectedWS - 1].ResourceID)

    }
    else
    {
        Throw "No OMS workspaces available in selected subscription $SubscriptionID"
    }
}

# Determine which resourcetype to search on
[array]$ResourcesToCheck = @()
[array]$DiagnosticCapable=@()
[array]$Logcategories = @()

# Build parameter set according to parameters provided.
$FindResourceParams = @{}
if($ResourceType)
{
    $FindResourceParams['ResourceType'] = $ResourceType
}
if($ResourceGroupName)
{
    $FindResourceParams['ResourceGroupNameEquals'] = $ResourceGroupName
}
if($ResourceName)
{
    $FindResourceParams['ResourceNameEquals'] = $ResourceName
}
$ResourcesToCheck = Find-AzureRmResource @FindResourceParams 

# If resourceType defined, ensure it can support diagnostics configuration
if($ResourceType)
{
    try
    {
        $Resources = $ResourcesToCheck
        $DiagnosticCapable = Get-ResourceType -allResources $Resources
        [int]$ResourceTypeToProcess = 0
        if ( $DiagnosticCapable.Count -eq 1)
        {
            $ResourceTypeToProcess = 1
        }
    }
    catch
    {
        Throw "No diagnostic capable resources of type $ResourceType available in selected subscription $SubscriptionID"
    }

}

# Gather a list of resources supporting Azure Diagnostic logs and metrics and display a table
if(!($ResourceType))
{
    Write-Host "Gathering a list of monitorable Resource Types from Azure Subscription ID " -NoNewline -ForegroundColor Cyan
    Write-Host "$SubscriptionId..." -ForegroundColor Yellow
    try
    {
        $DiagnosticCapable = Add-IndexNumberToArray (Get-ResourceType $ResourcesToCheck).where({$_.metrics -eq $True -or $_.Logs -eq $True}) 
        [int]$ResourceTypeToProcess = 0
        if ( $DiagnosticCapable.Count -eq 1)
        {
            $ResourceTypeToProcess = 1
        }
        while($ResourceTypeToProcess -gt $DiagnosticCapable.Count -or $ResourceTypeToProcess -lt 1 -and $Force -ne $True)
        {
            Write-Host "The table below are the resource types that support sending diagnostics to Log Analytics"
            $DiagnosticCapable | select "#", ResourceType, Metrics, Logs |ft
            try
            {
                $ResourceTypeToProcess = Read-Host "Please select a number from 1 - $($DiagnosticCapable.count) to enable (""True"" = supported configuration)"
            }
            catch
            {
                Write-Warning -Message 'Invalid option, please try again.'
            }
        }
        $ResourceType = $DiagnosticCapable[$ResourceTypeToProcess -1].ResourceType
        # Find all resources for $ResourceType defined
        $Resources = $ResourcesToCheck.where({$_.ResourceType -eq $ResourceType})
    }
    catch
    {
        Throw "No diagnostic capable resources available in selected subscription $SubscriptionID"
    }
}

# Convert string to array 
if($CategoriesChosen)
{
    # Trim spaces out
    $CategoriesChosen = $CategoriesChosen.replace(" ","")
    
    # Define our array of log categories
    [array]$Logcategories = ($CategoriesChosen -split ",")
}

# If Logs is $True and categories not defined - prompt for categories to enable
if(!($CategoriesChosen) -and !($Force) -and !($EnableLogs) -and !($DisableLogs) -and $DiagnosticCapable[$ResourceTypeToProcess -1].logs -eq $True)
{
    foreach($Diag in $DiagnosticCapable.where({$_.ResourceType -eq $ResourceType}))
    {
        $CategoryList = $Diag.Categories

        $CAnalysis=@()
        $CategoriesChosen = @()
        if($Diag.ResourceType -eq $ResourceType)
        {
            foreach($Category in $CategoryList)
            {
                $cObject = New-Object -TypeName PSObject -Property @{'Categories' = $Category; 'ResourceType' = $ResourceType}| ` 
                    select 'Categories', 'ResourceType'
                $CAnalysis += $CObject
            }
        }
        $Canalysis = Add-IndexNumberToArray ($CAnalysis) 
        Write-Host "The following categories are available for logs for $ResourceType"
        $CAnalysis|select "#",Categories, ResourceType|ft
        [array]$Logcategories =@()
        
        [array]$CategoriesChosen = (Read-host "Please provide # of log(s) to process (separated by a comma) or type ALL").ToUpper()
        
        if($CategoriesChosen[0] -eq "ALL")
        {
            foreach($Category in $CAnalysis)
            {
                $Logcategories = $Logcategories + $($Category.Categories)
            }
        }
        elseif($CategoriesChosen -ne $Null)
        {
            # Trim spaces out
            $CategoriesChosen = $CategoriesChosen.replace(" ","")
           
            [array]$CategoriesChosen = ($CategoriesChosen -split ",")
            
            foreach($Category in $CategoriesChosen)
            {
                $Logcategories = $Logcategories + $($CAnalysis[$Category-1].Categories)
            }
        }
        Write-Host "You Chose the following"
        foreach($Line in $Logcategories)
        {
            write-host $Line -ForegroundColor Yellow
        }            
    }
}
[array]$CategoriesChosen = $Logcategories

# Validate customer wants to continue to update all resources in ResourceType selected
# If Force used, will update without prompting
if ($Force -OR $PSCmdlet.ShouldContinue("This operation will update $($Resources.Count) $ResourceType resources in your subscription. Continue?",$ResourceType) )
{
        Write-Host "Configuring $($Resources.Count) [$ResourceType] resources in your subscription." 
        Set-Resource -Resources $Resources -Update:$Update -WSID $WSID -CategoryArray $CategoriesChosen `
            -DisableLogs:$DisableLogs -DisableMetrics:$DisableMetrics `
            -EnableMetrics:$EnableMetrics -EnableLogs:$EnableLogs `
            -DiagnosticCapability $DiagnosticCapable[$ResourceTypeToProcess -1]
        Write-Host "Complete" -ForegroundColor Cyan
}
else
{
        Write-Host "You selected No - exiting"
        Write-Host "Complete" -ForegroundColor Cyan
}