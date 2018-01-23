Project status : Ready

# Pre GA DEPLOYMENT
## PLEASE DO NOT FORK, OR PROVIDE BUGS IN GIT 
## CONTACT frasim@microsoft.com WITH ANY ISSUES, OR CHANGES


## To run the solution please review requirements:

1. Must have a subscription where you have access and can manage the GLOBAL ADMIN. 

### FOR MSFT EMPLOYEES - Subscriptions can be set up using ARIS - https://azuremsregistration.cloudapp.net/Request.aspx
-  You must select - External test or External Demo for access to a DS that is not associated with MSFT Domain.
- ALSO NOTE THAT RUNNING THIS SCRIPT FROM HOST ON MSFT WILL FAIL, DUE TO MSFT FIREWALL RULES.


2. Follow the **[deployment instructions](./AzureHealthDocs.md) **


I've also posted a video and blueprint deck you can view on how the solution works, and what you can expect when deploying it. 
https://1drv.ms/f/s!AuGGBuEyUCt7j69YoWIiOZBC3euOOA 


## Quick Deployment steps
1. You will need a clean VM to deploy the solution
- Launch your VM (windows 10)
- How to stand up a VM https://docs.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-portal 
2.	Download or clone this repo to your new VM
3.  Open a PowerShell in Admin mode
4.	Run ```Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force``` 
5.	Run ```deploy.ps1 -installmodules ``` in the deployment directory
6.	Run ``` .\deploy.ps1 -deploymentPrefix <PREFIX> -tenantId <ID> -tenantDomain <DOMAIN> -subscriptionId <SUBSCRIPTION> -globalAdminUsername <ADMIN@ONMICROSOFT.COM> -deploymentPassword <A SINGLE PASSWORD> ```  
7.	Follow manual config steps from doc steps ‘Integrate Application Insights Log Analytics’
8.	Run ``` .\HealthcareDemo.ps1 -deploymentPrefix prefix -Operation BulkPatientAdmission ```
9.	Run ``` .\HealthcareDemo.ps1 -deploymentPrefix prefix -Operation Ingestion ```
10.	Check your database, ML, and PowerBI for data accuracy from SQL explorer 
  ``` SELECT TOP 20 *  FROM [dbo].[PatientData]  ORDER by eID desc ```


# Compliance Content
Additional content 
- Threat model
- HITRUST Customer Responsibility Matrix
Supporting material for solution can be found at https://github.com/Azure/HIPAA-Healthcare-ML-LOS/tree/master/Documents/Compliance


# Contribute
 The deployment script is designed to deploy the core elements of the Azure Healthcare Length of Stay solution. The details of the solutions operation, and elements can be reviewed at aka.ms/healthcareblueprint
Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.





