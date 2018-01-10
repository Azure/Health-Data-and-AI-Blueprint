#
# HealthcareDemo.ps1
# 
# performs hospital patient data ingestion, patient admission and discharge operations.
#

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [Alias("prefix")]
    [ValidateLength(1,5)]
    [ValidatePattern("[a-zA-Z][a-zA-Z0-9]")]
	[string]$deploymentPrefix,

	[parameter(Mandatory=$true)]
	[ValidateSet("Ingestion","BulkPatientAdmission","BulkPatientDischarge")]
	[string]$Operation
)

# globals

$scriptPath = Split-Path $MyInvocation.MyCommand.Path
Import-Module "$scriptPath/lib.psm1"
$scriptRoot = Split-Path (Split-Path ( Split-Path $MyInvocation.MyCommand.Path ))
$clinicalStatus="active","recurrence" ,"inactive" , "remission", "resolved"
$gender="male","female"
$vDates=5,7,10,7,12,13
$deploymentprefix = $deploymentprefix.ToLower()

switch($Operation){
	Ingestion{
                if (Test-Path "$scriptroot\trainingdata\LengthOfStayname.csv" ) {
                    $blobPath = "$scriptroot\trainingdata\LengthOfStayname.csv"
                }
                else {
                    Write-Host "`nFailed to find LOS Training Data CSV file. Please enter valid path for CSV" -ForegroundColor Red
                    $blobPath = Read-Host "Enter File Path"
                }
                ### Create PSCredential Object for GlobalAdmin Account
                $deploymentOutput = Get-Content -Path "$scriptroot\output\$($deploymentPrefix)-deploymentOutput.json" | ConvertFrom-Json
                $password = ConvertTo-SecureString -String $deploymentOutput.DeploymentPassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($deploymentOutput.UPN_DataScientistUser, $password)
                Write-Host -ForegroundColor Yellow "`nConnecting to AzureRM Subscription using $($deploymentOutput.UPN_DataScientistUser) Account."
                $azureRMContext = Login-AzureRmAccount -Credential $credential -ErrorAction SilentlyContinue
                if($azureRMContext-ne $null){
                    Write-Host -ForegroundColor Green "`nConnection was successful." 
                }
                Else{
                    Write-Host -ForegroundColor Red "`nFailed connecting to Azure." 
                    break
                }
                try {
                    Write-Host -ForegroundColor Yellow "`nGetting StorageAccessKey for Storage Account - $($deploymentOutput.BlobStorageAccountName)"
                    $storageAccessKey = (Get-AzureRmStorageAccount | Where-Object StorageAccountName -eq $deploymentOutput.BlobStorageAccountName | Get-AzureRmStorageAccountKey)[0].Value
                    Write-Host -ForegroundColor Yellow "`nCreating Azure storage context to upload LOS data."
                    $storageContext = New-AzureStorageContext -StorageAccountName $deploymentOutput.BlobStorageAccountName -StorageAccountKey $storageAccessKey
                    Write-Host -ForegroundColor Yellow "`nUploading LOS data.."
                    Set-AzureStorageBlobContent -File $blobPath -Container 'trainingdata' -Context $storageContext
                    Write-Host -ForegroundColor Yellow "`nLOS data uploaded successfully. "
                }
                catch {
                     Write-Host "error : $_"
                }
	}
	BulkPatientAdmission{
		try {
				Write-Host "getting app details..." -Foregroundcolor Yellow
				$deploymentOutput = Get-Content -Path "$scriptroot\output\$($deploymentPrefix)-deploymentOutput.json" | ConvertFrom-Json
				
				Write-Host "getting data format..." -Foregroundcolor Yellow
				$patientInput = 
					Get-Content -Path $scriptroot\scripts\jsonscripts\input_admission.json | ConvertFrom-Json

				Write-Host "please login..." -Foregroundcolor DarkGray
				$token = Get-AuthToken -tenantId $deploymentOutput.AADTenantId -clientId $deploymentOutput.AADApplicationClientId -clientSecret $deploymentOutput.DeploymentPassword -replyUrl $deploymentOutput.AADAppReplyUrl

				Write-Host "obtained authentication token.." -ForegroundColor Yellow

				$files = (Get-ChildItem admit -Filter "*.json").FullName

				$countAdmitted = 0
				$fhir=""
				$output=""
				$fhirJson=""
				$vcount=0
				foreach($file in $files){

					$fhir = (Get-Content -Path $file) | ConvertFrom-Json
					$fhir.encounter.period.start=[DateTime]::Now.AddDays(-1*$vDates[$vcount]).ToString("yyyy-MM-ddThh:mm:sszzz")
					$fhirJson=$fhir | ConvertTo-Json -Depth 5
					$output = Invoke-HealthcareFunction -accessToken $token -httpMethod Post -data $fhirJson -functionUrl $deploymentOutput.AzFunc_AdmissionFunctionUrl
					
					if($output.result -ne "invalid encounter id" -and $output.result -ne "failed"){
						$countAdmitted++
					}

					$vcount++
				}

				Write-Host "patient admitted count : $countAdmitted" -ForegroundColor DarkCyan
             }
		catch {
				 Write-Host "error : $_"
			}
	}
	BulkPatientDischarge{
		 try {

                Write-Host "getting app details..." -Foregroundcolor Yellow
                $deploymentOutput = Get-Content -Path "$scriptroot\output\$($deploymentPrefix)-deploymentOutput.json" | ConvertFrom-Json
			
				Write-Host "getting data format..." -Foregroundcolor Yellow
				$patientInput = 
					Get-Content -Path $scriptroot\scripts\jsonscripts\input_discharge.json | ConvertFrom-Json
				
				Write-Host "please login..." -Foregroundcolor DarkGray
				$token = Get-AuthToken -tenantId $deploymentOutput.AADTenantId -clientId $deploymentOutput.AADApplicationClientId -clientSecret $deploymentOutput.DeploymentPassword -replyUrl $deploymentOutput.AADAppReplyUrl
				
				Write-Host "obtained authentication token..." -Foregroundcolor Yellow

				$files = (Get-ChildItem discharge -Filter "*.json").FullName

				$countDischarged = 0
				$fhir=""
				$output=""
				$fhirJson=""
				foreach($file in $files){

					$fhir = (Get-Content -Path $file) | ConvertFrom-Json
					$fhir.encounter.period.end = [DateTime]::Now.ToString("yyyy-MM-ddThh:mm:sszzz")
					$fhirJson = $fhir | ConvertTo-Json -Depth 5
					$output = Invoke-HealthcareFunction -accessToken $token -httpMethod Put -data $fhirJson -functionUrl $deploymentOutput.AzFunc_DischargeFunctionUrl
					
					if($output.result -ne "invalid encounter id" -and $output.result -ne "failed"){
						$countDischarged++
					}
				}

				Write-Host "patient discharged count : $countDischarged" -ForegroundColor DarkCyan
             }
         catch {
                 Write-Host "error : $_" -ForegroundColor Red
             }
	}
}


