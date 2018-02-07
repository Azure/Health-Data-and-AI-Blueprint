---
title: Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI FAQ
description: Guidance for deploying a Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI
author: simorjay
ms.date: 01/23/2018
---

# Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI FAQ


**Why am I unable to log in or run the PowerShell scripts with my Azure
subscription user?**

You are required to create an Azure Active Directory (AAD) administrator
as specified in the document. An active directory account is required because a subscription
admin does not automatically receive DS or AAD credentials. 

**I get the following error "cannot be loaded because running scripts is
disabled on this system. For more information, see
about\_Execution\_Policies"**

You can correct the permissions locally by running the following command:
```
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
```
For more information, see.

**When I run the deployment script, it tells me that a module is
missing**

The script requires the following PowerShell modules:

'AzureRM' = 4.4.0\
'AzureAD' = 2.0.0.131\
'SqlServer' = 21.0.17199\
'MSOnline' = 1.1.166.0

The script tries to unload and load the correct scripts running
deploy.ps1 -installmodule. If permissions are not set correctly
on the local computer. Or module permissions were changed. The script will not load the correct versions of the
required modules.

If a module fails it's recommended that you remove the modules from your PowerShell install directory, and then
rerun the deploy.ps1 -installmodule command.

**Why do I need to add my subscription administrator to the AAD Admin
role?**

Role-based access control requires that the deployment use administrator rights in AAD. For a detailed explanation, see:

-   [Delegating Admin Rights in Microsoft
    Azure](https://www.petri.com/delegating-admin-rights-in-microsoft-azure)

-   [PowerShell - Connecting to Azure Active Directory using Microsoft
    Account](http://stackoverflow.com/questions/29485364/powershell-connecting-to-azure-active-directory-using-microsoft-account)

**Are there third-party solutions that can help achieve or manage
Healthcare HIPAA / HITRUST compliance?**

Third-party products can help with continuous compliance efforts.
Examples of the products available in the Azure marketplace:

- **Continuous Compliance Monitoring**       [Cloudneeti - - Cybersecurity & Compliance Assurance](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/cloudneeti.cloudneeti_enterpise?tab=Overview)
- **Network Security and Management**        [Azure Marketplace: Network Security](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/networking?page=1)
- **Extending Identity Security**            [Azure Marketplace: Security + Identity](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/security-identity?page=1)
- **Extending Monitoring and Diagnostics**   [Azure Marketplace: Monitoring + Diagnostics](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/monitoring-management?page=1&subcategories=monitoring-diagnostics)


**Why do I need to set up some permissions, Security Center, and OMS
ingestion manually?**

Some monitoring capabilities do not offer hooks to automate at this
time. See the deployment guidance documents for instructions for
enabling the features manually.

**Why does the Resource Manager template fail to run because of my password
complexity?**

Strong passwords are recommended
throughout the solution, for example, 15 characters, with upper and lower-case
letters, at least 1 number, and 1 special character. 

**How do I use this solution in my production deployment environment?**

This solution (including the scripts, template, and documentation) is
designed to help you build a pilot or demo site. Using this solution
does not provide a ready-to-production solution.
This solution illustrates the components required to build a more secure end-to-end
solution. 


**What else should I consider once the solution is installed?**

Once the script has completed, you should consider resetting your
administrative passwords, including your ADsqladmin and Admin users. The
following command can be used to quickly reset passwords in PowerShell:
```
Set-MsolUserPassword -userPrincipalName *\<youradmin@yourdomain\>*-NewPassword *\<newpassword\>* ‑ForceChangePassword \$false
```
**When I Run .\\HealthcareDemo.ps1 -deploymentPrefix prefix -Operation
Ingestion I get a permission error.**

The script was not provided the correct permissions. To grant permissions in Azure Active Directory:

1.  In the Azure portal, click **Azure Active Directory** in the
    sidebar.

2.  Click **App registrations**.

3.  Click *\<deployment-prefix\>* **Azure HIPAA LOS Sample**.

4.  Click **Required permissions**.

5.  Click **Grant Permissions** at top. You are asked if you want to
    grant permissions for all accounts in the current directory. Click
    **Yes**.
	
**I redeploy the solution after an error... and it fails due to a 'cache' error, such as a token is duplicate**

Due to PowerShell's limitations, caching users information may at times cause errors. It's recommended you close and reopen your PowerShell session to clear any local caches. 

**I get an error while deployment at 'appInsights' step of the script. I noticed the error is related to a /CurrentBillingFeatures**
![](images/OMSlicense.png)

The error is due to the licensing model of your OMS/appInsights. You can correct the script by adding an enterprise plan in Azure Portal, or changing the deployment method:
0 – Set up App Insights with Application Insights Basic Plan.

1 – Set up App insights with Application Insights Enterprise Plan.

2 –  Only deploys App Insights without any billing plan. 

Subscriptions such as BizSpark, where there is a spending limit, the use of option "2" is required. 
```
.\deploy.ps1 -deploymentPrefix <1-5-length-prefix> `
             -tenantId <tenant-id> `
             -tenantDomain <tenant-domain> `
             -subscriptionId <subscription-id> `
             -globalAdminUsername <username> `
             -deploymentPassword Hcbnt54%kQoNs62`
             -appInsightsPlan 2            
```

# Disclaimer and acknowledgments
February 2018

This document is for informational purposes only. MICROSOFT AND AVYAN MAKE NO WARRANTIES, EXPRESS, IMPLIED, OR STATUTORY, AS TO THE INFORMATION IN THIS DOCUMENT. This document is provided “as-is.” Information and views expressed in this document, including URL and other Internet website references, may change without notice. Customers reading this document bear the risk of using it.
This document does not provide customers with any legal rights to any intellectual property in any Microsoft or Avyan product or solutions.
Customers may copy and use this document for internal reference purposes.

**Note**

Certain recommendations in this solution may result in increased data, network, or compute resource usage in Azure. The solution may increase a customer’s Azure license or subscription costs.

The solution in this document is intended as an architecture and must not be used as-is for production purposes. Achieving Health compliance (such as HIPAA, or HITRUST) requires that customers consult with compliance or audit office.  

All customer names, transaction records, and any related data on this page are fictitious, created for the purpose of this architecture, and provided for illustration only. No real association or connection is intended, and none should be inferred.
This solution was designed by Microsoft with development support from Avyan Consulting The work in its entirety, or parts is available under the [MIT License](https://opensource.org/licenses/MIT).
This solution has been reviewed by Coalfire, a Microsoft auditor. The HIPAA, and HITRUST Compliance Review provides an independent, third-party review of the solution, and components that need to be addressed.

