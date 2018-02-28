<#
.SYNOPSIS
This script is designed to provide the demo capabilities of the blueprint solution. The code located here is designed to help understand how you can securely upload a built data set, and import patient data for ML analysis and storage.

.DESCRIPTION

FHIR (Fast Healthcare Interoperability Resources) is a specification for exchanging healthcare data in a modern and developer friendly way.
FHIR Schemas used in the Healthcare Solution Blueprint
The current solution is made up of the following sample FHIR Schema -
	• Patient schema link - https://www.hl7.org/fhir/patient.html
	• Observation schema link - https://www.hl7.org/fhir/observation.html
	• Encounter schema link - https://www.hl7.org/fhir/encounter.html
	• Condition schema link - https://www.hl7.org/fhir/condition.html

Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.EXAMPLE

.\HealthcareDemo.ps1 -deploymentPrefix <deployment-prefix> -Operation Ingestion

To input the sample historical patient data into the solution.

.EXAMPLE

.\HealthcareDemo.ps1 -deploymentPrefix <deployment-prefix> -Operation BulkPatientAdmission

Adds newly admitted patients to the database by uploading their information in FHIR format.

.EXAMPLE

.\HealthcareDemo.ps1 -deploymentPrefix <deployment-prefix> -Operation BulkPatientDischarge

Discharges patients to the database by uploading discharge information in FHIR format.

#>

[CmdletBinding()]
param
(
	#Deployment prefix of the deployed solution
    [Parameter(Mandatory = $true)]
    [Alias("prefix")]
    [ValidateLength(1,5)]
    [ValidatePattern("[a-zA-Z][a-zA-Z0-9]")]
	[string]$deploymentPrefix,

	#Healthcare operation (ingestion/bulk admission/bulk discharge)
	[parameter(Mandatory=$true)]
	[ValidateSet("Ingestion","BulkPatientAdmission","BulkPatientDischarge")]
	[string]$Operation
)

# global variables
$ErrorActionPreference = 'Stop'

#script path
$scriptPath = Split-Path $MyInvocation.MyCommand.Path

#import dependent module
Import-Module "$scriptPath/lib.psm1"

#script root
$scriptRoot = Split-Path (Split-Path ( Split-Path $MyInvocation.MyCommand.Path ))

#Sample FHIR defined patient status.
$clinicalStatus="active","recurrence" ,"inactive" , "remission", "resolved"

#Sample FHIR defined gender
$gender="male","female"

#Sample dates used for patient admission
$vDates=5,7,10,7,12,13

#Deployment prefix passed during the deployment
$deploymentprefix = $deploymentprefix.ToLower()

switch($Operation){
	Ingestion{
				# The LengthOfStayname.csv provides a dataset used for the experiments throughout this Blueprint. Replacing the csv will not guarantee that importing of data will succeed.
                if (Test-Path "$scriptroot\trainingdata\LengthOfStayname.csv" ) {
                    $blobPath = "$scriptroot\trainingdata\LengthOfStayname.csv"
                }
                else {
                    Write-Host "`nFailed to find LOS Training Sample Data CSV file. Please enter valid path for CSV" -ForegroundColor Red
                    $blobPath = Read-Host "Enter File Path"
                }
                ### Create PSCredential Object for GlobalAdmin Account
                $deploymentOutput = Get-Content -Path "$scriptroot\output\$($deploymentPrefix)-deploymentOutput.json" | ConvertFrom-Json
                $password = ConvertTo-SecureString -String $deploymentOutput.DeploymentPassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($deploymentOutput.UPN_DataScientistUser, $password)
                Write-Host -ForegroundColor Yellow "`nConnecting to AzureRM Subscription using $($deploymentOutput.UPN_DataScientistUser) Account."
				Write-Host "Connecting to the Debra_DataScientist Account." -ForegroundColor Yellow
				try {
					Login-AzureRmAccount -Credential $credential
					Write-Host "Established connection to Debra_DataScientist Account." -ForegroundColor Green
				}
				catch {
					Write-Host "$($Error[0].Exception.Message)" -ForegroundColor Yellow
					Write-Host -ForegroundColor Cyan "`nEnter Debra_DataScientist credentials manually. Please refer deploymentOutput.json for deployment password."
					Login-AzureRmAccount
				}

                try {
                    Write-Host -ForegroundColor Yellow "`nRetrieving StorageAccessKey for Storage Account - $($deploymentOutput.BlobStorageAccountName)"
                    $storageAccessKey = (Get-AzureRmStorageAccount | Where-Object StorageAccountName -eq $deploymentOutput.BlobStorageAccountName | Get-AzureRmStorageAccountKey)[0].Value
                    Write-Host -ForegroundColor Yellow "`nCreating Azure storage context to upload LOS data."
					$storageContext = New-AzureStorageContext -StorageAccountName $deploymentOutput.BlobStorageAccountName -StorageAccountKey $storageAccessKey
					Write-Host "Connecting to $($deploymentOutput.BlobStorageAccountName). Uploading Sample CSV data to storage container - 'trainingdata'"
                    Set-AzureStorageBlobContent -File $blobPath -Container 'trainingdata' -Context $storageContext
                    Write-Host -ForegroundColor Yellow "`nSample CSV data uploaded."
                }
                catch {
                     Write-Host "error : $_"
                }
	}
	BulkPatientAdmission{
		try {
				Write-Host "Retrieving installation configuration from deploymentoutput.json" -Foregroundcolor Yellow
				$deploymentOutput = Get-Content -Path "$scriptroot\output\$($deploymentPrefix)-deploymentOutput.json" | ConvertFrom-Json
				
				Write-Host "Reading \scripts\jsonscripts\input_admission.json" -Foregroundcolor Yellow
				$patientInput = 
					Get-Content -Path $scriptroot\scripts\jsonscripts\input_admission.json | ConvertFrom-Json

                #Login using Chris_CareLineManager and obtain authentication token from Get-AuthToken in .\lib.psm1
				Write-Host "Pop-up login dialog box requires attention." -Foregroundcolor Yellow
				Write-Host "Use username - Chris_CareLineManager@<DOMAIN> and password used during setup.  Refer to '\output\<deploymentPrefix>-deploymentOutput.json' for deployment password. Ensure permissions have been set correctly; see FAQ ‘access_denied’ Setting for correct use. " -Foregroundcolor Yellow
				$token = Get-AuthToken -tenantId $deploymentOutput.AADTenantId -clientId $deploymentOutput.AADApplicationClientId -clientSecret $deploymentOutput.DeploymentPassword -replyUrl $deploymentOutput.AADAppReplyUrl

				Write-Host "Obtained authentication token." -ForegroundColor Yellow

				#Get patient admission json files \scripts\demoscripts\admit_10000x.json
				$files = (Get-ChildItem admit -Filter "*.json").FullName

                #Import 10 sample patients into solution
				$countAdmitted = 0
				$fhir=""
				$output=""
				$fhirJson=""
				$vcount=0
				foreach($file in $files){
					$fhir = (Get-Content -Path $file) | ConvertFrom-Json
					$fhir.encounter.period.start=[DateTime]::Now.AddDays(-1*$vDates[$vcount]).ToString("yyyy-MM-ddThh:mm:sszzz")
					$fhirJson=$fhir | ConvertTo-Json -Depth 5
					#call admission azure function over rest using input data $fhirJson and access token
					Write-Host "Calling $($deploymentOutput.AzFunc_AdmissionFunctionUrl) and POSTing data for $file"
					$output = Invoke-HealthcareFunction -accessToken $token -httpMethod Post -data $fhirJson -functionUrl $deploymentOutput.AzFunc_AdmissionFunctionUrl
					if($output.result -ne "invalid encounter id" -and $output.result -ne "failed"){
						$countAdmitted++
					}

					$vcount++
				}

				Write-Host "Total patient admitted : $countAdmitted" -ForegroundColor DarkCyan
             }
		catch {
				 Write-Host "error : $_" -ForegroundColor Red
			}
	}
	BulkPatientDischarge{
		 try {

                Write-Host "Retrieving installation configuration from deploymentoutput.json" -Foregroundcolor Yellow
                $deploymentOutput = Get-Content -Path "$scriptroot\output\$($deploymentPrefix)-deploymentOutput.json" | ConvertFrom-Json
				
				Write-Host "Reading \scripts\jsonscripts\input_discharge.json" -Foregroundcolor Yellow
				$patientInput = 
					Get-Content -Path $scriptroot\scripts\jsonscripts\input_discharge.json | ConvertFrom-Json
				
                #Login using Chris_CareLineManager and obtain authentication token from Get-AuthToken in .\lib.psm1
				Write-Host "Pop-up login dialog box requires attention." -Foregroundcolor Yellow
				Write-Host "Use username - Chris_CareLineManager and deployment password, refer to '\output\<deploymentPrefix>-deploymentOutput.json for deployment password." -Foregroundcolor DarkGray
				$token = Get-AuthToken -tenantId $deploymentOutput.AADTenantId -clientId $deploymentOutput.AADApplicationClientId -clientSecret $deploymentOutput.DeploymentPassword -replyUrl $deploymentOutput.AADAppReplyUrl
				
				Write-Host "Obtained authentication token." -ForegroundColor Yellow

                #Get patient admission json files \scripts\demoscripts\discharge_10000x.json
				$files = (Get-ChildItem discharge -Filter "*.json").FullName

                #Discharge 6 sample patients from solution
				$countDischarged = 0
				$fhir=""
				$output=""
				$fhirJson=""
				foreach($file in $files){

					$fhir = (Get-Content -Path $file) | ConvertFrom-Json
					$fhir.encounter.period.end = [DateTime]::Now.ToString("yyyy-MM-ddThh:mm:sszzz")
					$fhirJson = $fhir | ConvertTo-Json -Depth 5

					#call discharge azure function over rest using input data $fhirJson and access token
					Write-Host "Calling $($deploymentOutput.AzFunc_DischargeFunctionUrl) and POSTing data for $file"
					$output = Invoke-HealthcareFunction -accessToken $token -httpMethod Put -data $fhirJson -functionUrl $deploymentOutput.AzFunc_DischargeFunctionUrl
					
					if($output.result -ne "invalid encounter id" -and $output.result -ne "failed"){
						$countDischarged++
					}
				}

				Write-Host "Total patient discharged : $countDischarged" -ForegroundColor DarkCyan
             }
         catch {
                 Write-Host "error : $_" -ForegroundColor Red
             }
	}
}


