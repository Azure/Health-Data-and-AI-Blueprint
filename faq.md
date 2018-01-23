---
title: Azure Health Analytics Blueprint FAQ
description: Guidance for deploying a HIPAA/HITRUST Health Analytics Blueprint 
author: simorjay
ms.date: 01/23/2018
---

# Azure Health Analytics Blueprint FAQ


**Why am I unable to login or run the PowerShell scripts with my Azure
subscription user?**

You are required to create an Azure Active Directory (AAD) administrator
as specified in the document. This is required because a subscription
admin does not automatically receive DS or AAD credentials. This is a
security feature that enables RBAC and role separation in Azure.

**I get the following error "cannot be loaded because running scripts is
disabled on this system. For more information, see
about\_Execution\_Policies"**

You will need to allow for the script to run by using the following
command:
```
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
```
For more information, see
<https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-5.1>.

**When I run the deployment script, it tells me that a module is
missing**

The script requires the following PowerShell modules:

'AzureRM' = 4.4.0\
'AzureAD' = 2.0.0.131\
'SqlServer' = 21.0.17199\
'MSOnline' = 1.1.166.0

The script will try to unload and load the correct scripts running
deploy.ps1 -installmodule. However, if permissions are not set correctly
on the local computer or if module permissions were changed, it is
possible the script will not be able to set the correct versions of the
modules.

If a module fails and will not load the correct version, remove the
modules in question from your PowerShell install directory, and then
rerun the deploy.ps1 -installmodule command.

**Why do I need to add my subscription administrator to the AAD Admin
role?**

Role-based access control requires that an administrator be granted
administrative rights in AAD. For a detailed explanation, see:

-   [Delegating Admin Rights in Microsoft
    Azure](https://www.petri.com/delegating-admin-rights-in-microsoft-azure)

-   [PowerShell - Connecting to Azure Active Directory using Microsoft
    Account](http://stackoverflow.com/questions/29485364/powershell-connecting-to-azure-active-directory-using-microsoft-account)

**Are there third-party solutions that can help achieve or manage
Healthcare HIPAA / HITRUST compliance?**

Third-party products can help with continuous compliance efforts.
Examples of the products available in the Azure marketplace are listed
below.

- **Continuous Compliance Monitoring**       [Cloudneeti - - Cybersecurity & Compliance Assurance](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/cloudneeti.cloudneeti_enterpise?tab=Overview)
- **Network Security and Management**        [Azure Marketplace: Network Security](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/networking?page=1)
- **Extending Identity Security**            [Azure Marketplace: Security + Identity](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/security-identity?page=1)
- **Extending Monitoring and Diagnostics**   [Azure Marketplace: Monitoring + Diagnostics](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/category/monitoring-management?page=1&subcategories=monitoring-diagnostics)


**Why do I need to set up some permissions, Security Center, and OMS
ingestion manually?**

Some monitoring capabilities do not offer hooks to automate at this
time. See the deployment guidance documents for instructions for
enabling the features manually.

**Why does the ARM template fail to run because of my password
complexity?**

Strong passwords (minimum 15 characters, with upper and lower-case
letters, at least 1 number, and 1 special character) are recommended
throughout the solution.

**How do I use this solution in my production deployment environment?**

This solution (including the scripts, template, and documentation) is
designed to help you build a pilot or demo site. Using this solution
does not provide a ready-to-production solution for customers; it only
illustrates the components required to build a more secure end-to-end
solution. For example, virtual network address spacing, NSG routing,
existing Storage and databases, existing enterprise-wide OMS workspaces
and solutions, Azure Key Vault rotation policies, usage of existing AD
admins and RBAC roles, and usage of existing AD applications and service
principals will require customization to meet the requirements of your
custom solution in production.

**What else should I consider once the solution is installed?**

Once the script has completed, you should consider resetting your
administrative passwords, including your ADsqladmin and Admin users. The
following command can be used to quickly reset passwords in PowerShell:
```
Set-MsolUserPassword -userPrincipalName *\<youradmin@yourdomain\>*-NewPassword *\<newpassword\>* ‑ForceChangePassword \$false
```
**When I Run .\\HealthcareDemo.ps1 -deploymentPrefix prefix -Operation
Ingestion I get a permission error.**

This is because you did not provide permissions to the application
during the installation. To grant permissions in Azure Active Directory:

1.  In the Azure portal, click **Azure Active Directory** in the
    sidebar.

2.  Click **App registrations**.

3.  Click *\<deployment-prefix\>* **Azure HIPAA LOS Sample**.

4.  Click **Required permissions**.

5.  Click **Grant Permissions** at top. You will be asked if you want to
    grant permissions for all accounts in the current directory. Click
    **Yes**.

# Disclaimer and acknowledgements
February 2017

This document is for informational purposes only. MICROSOFT AND AVYAN MAKE NO WARRANTIES, EXPRESS, IMPLIED, OR STATUTORY, AS TO THE INFORMATION IN THIS DOCUMENT. This document is provided “as-is.” Information and views expressed in this document, including URL and other Internet website references, may change without notice. Customers reading this document bear the risk of using it.
This document does not provide customers with any legal rights to any intellectual property in any Microsoft or Avyan product or solutions.
Customers may copy and use this document for internal reference purposes.

**Note**

Certain recommendations in this material may result in increased data, network, or compute resource usage in Azure, and may increase a customer’s Azure license or subscription costs.

The solution in this document is intended as a architecture and must not be used as-is for production purposes. Achieving Health compliance (such as HIPAA, or HITRUST) requires that customers consult with compliance or audit office.  

All customer names, transaction records, and any related data on this page are fictitious, created for the purpose of this architecture and provided for illustration only. No real association or connection is intended, and none should be inferred.
This solution was designed by Microsoft with development support from Avyan Consulting The work in it's entirety, or parts is available under the [MIT License](https://opensource.org/licenses/MIT).
This solution has been reviewed by Coalfire, a Microsoft auditor. The HIPAA, and HITRUST Compliance Review provides an independent, third-party review of the solution, and components that need to be addressed.

# Document authors

Frank Simorjay (Microsoft)