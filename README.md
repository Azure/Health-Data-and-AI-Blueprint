# Pre GA DEPLOYMENT
## PLEASE DO NOT FORK, OR PROVIDE BUGS IN GIT 
## CONTACT frasim@microsoft.com WITH ANY ISSUES, OR CHANGES


## To run the solution please review requirements:

1. Must have a subscription where you have access and can manage the GLOBAL ADMIN. 

### FOR MSFT EMPLOYEES - If not you will need to set one up via ARIS - https://azuremsregistration.cloudapp.net/Request.aspx
-  You must select - External test or External Demo for access to a DS that is not associated with MSFT
- ALSO NOTE THAT RUNNING THIS SCRIPT FROM HOST ON MSFT WILL FAIL, DUE TO MSFT FIREWALL RULES.


2. Follow the instructions on deploying the solution 
- Read Azure Healthcare Blueprint.docx (deployment document)
https://github.com/Azure/HIPAA-Healthcare-ML-LOS/tree/master/Documents/Content


I've also posted a video and blueprint deck you can view on how the solution works, and what you can expect when deploying it. 
https://microsoft-my.sharepoint.com/:f:/p/frasim/ElfAwXiJbVZIuqr48_hnQ3wBqeHH8b9ONhWuBYvywXY5pw?e=3MyEaG


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




# Contribute
 The deployment script is designed to deploy the core elements of the Azure Healthcare Length of Stay solution. The details of the solutions operation, and elements can be reviewed at aka.ms/healthcareblueprint
Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


## FAQ

## Why am I unable to login or run the PowerShell scripts with my Azure subscription user? ##
You are required to create an Azure Active Directory (AAD) administrator as specified in the document. This is required because a subscription admin does not automatically receive DS or AAD credentials. This is a security feature that enables RBAC and role separation in Azure.

## I get the following error "cannot be loaded because running scripts is disabled on this system. For more information, see about_Execution_Policies" ##
You will need to allow for the script to run by using the following command
'''
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
'''
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-5.1

## When I run the deployment script, it tells me that a module is missing ##
The script requires the following powershell modules :
    'AzureRM' = 4.4.0
    'AzureAD' = 2.0.0.131
    'SqlServer' = 21.0.17199
    'MSOnline' = 1.1.166.0
The script will try and unload and load the correct scripts running deploy.ps1 -installmodule. However if permissions are not set correctly on the local PC, or module permissions where changed it is possible the script will not be able to 'set' the correct versions to run correctly.
If a module fails and will not load the correct version, you can remove the modules in question from your powershell install directory, then rerun deploy.ps1 -installmodule.


## Why do I need to add my subscription administrator to the AAD Admin role? ##
>Role-based access control requires that an administrator be granted administrative rights in AAD. For a detailed explanation, see:
>- [Delegating Admin Rights in Microsoft Azure](https://www.petri.com/delegating-admin-rights-in-microsoft-azure)
>- [PowerShell - Connecting to Azure Active Directory using Microsoft Account](http://stackoverflow.com/questions/29485364/powershell-connecting-to-azure-active-directory-using-microsoft-account) 

## Are there third-party solutions that can help achieve or manage Healthcare HIPAA / HITRUST compliance?
> Third-party products can help with continuous compliance efforts. Examples of the products available in the Azure marketplace are listed below.

| Security Layer | Azure Marketplace Product(s) |
| --- | --- |
| Continuous Compliance Monitoring | [Cloudneeti -  - Cybersecurity & Compliance Assurance](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/cloudneeti.cloudneeti_enterpise?tab=Overview) |
| Network Security and Management | [Azure Marketplace: Network Security](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/networking?page=1) |
| Extending Identity Security | [Azure Marketplace: Security + Identity](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/security-identity?page=1) |
| Extending Monitoring and Diagnostics 	| [Azure Marketplace: Monitoring + Diagnostics](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/monitoring-management?page=1&subcategories=monitoring-diagnostics) |

## Why do I need to set up some , permissions, security center, and OMS ingestion manually ##
Some monitoring capabilities do not offer hooks to automate at this time. Instructions to enable the features manually will be provided in the deployment guidance documents.

## Why does the ARM template fail to run because of my password complexity? ##
Strong passwords (minimum 15 characters, with upper and lower-case letters, at least 1 number, and 1 special character) are recommended throughout the solution.

## How do I use this solution in my production deployment environment? ##
This solution (including the scripts, template, and documentation) is designed to help you build a pilot or demo site. Using this solution does not provide a ready-to-production solution for customers; it only illustrates the components required to build a secure and compliant end-to-end solution. For example virtual network address spacing, NSG routing, existing Storage and databases, existing enterprise-wide OMS workspaces and solutions, Azure Key Vault rotation policies, usage of existing AD admins and RBAC roles, and usage of existing AD applications and service principals will require customization to meet the requirements of your custom solution in production.

## What else should I consider once the solution is installed? ##
Once the script has completed, you should consider resetting your administrative passwords, including your ADsqladmin and Admin users. The following command can be used to quickly reset passwords in PowerShell.
```
Set-MsolUserPassword -userPrincipalName [youradmin@yourdomain] -NewPassword [NEWPASSWORD] -ForceChangePassword $false
```

## When I Run .\HealthcareDemo.ps1 -deploymentPrefix prefix -Operation Ingestion I get a permission error. ##

This is because you did not provide permissions to the application during the installation.
Grant permissions in Azure Active Directory
1.	In the Azure portal, click Azure Active Directory in the sidebar. 
2.	Click App registrations.
3.	Click <deployment-prefix> Azure HIPAA LOS Sample.
4.	Click Required permissions.
5.	Click Grant Permissions at top. You will be asked if you want to grant permissions for all accounts in the current directory. Click Yes.



