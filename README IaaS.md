

# Azure Security and Complaince Blueprint - HIPAA/HITRUST Health Data and AI - IaaS Extension 




The HIPAA/HITRUST Health Data and AI - IaaS Extension provides customers the ability to deploy the health blueprint and include a hybrid IaaS deployment. This helps with understanding how Azure Security Center and other security technologies such as end point host protection work in the Healthcare solution.

This solution will demonstarte hot to migrate an on-premises SQL based solution to Azure, and to implement a Privileged Access Workstation (PAW) to securely manage cloud-based services and solutions. The IaaS SQL Server database adds potential experimentation data is imported into a SQL IaaS VM, and that VM uses MSI authenticated access to interact a SQL Azure PaaS service.

This health data and AI extension is unique because it extends the PaaS Health-Data-and-AI-Blueprint, demonstrating best practices and possible approaches to address the following new points:

1. “Start Secure” – enable security capabilities and monitoring of the IaaS VM workload before any sensitive data or workload processing takes place.
2. Extend the existing PaaS sample to show secure co-existence between PaaS and IaaS VM workload elements.
3. Illustrate how to use recently introduced security and deployment capabilities.
4. Address the need to use a clean device when connecting to managment service in Azure.

The deployment of the IaaS VM includes usage of Azure Security Center, a network security group and network access lockdown, auto-update capability for patch management, usage of encryption at rest capabilities, usage of event log audit log collection and monitoring capabilities, usage of managed service identity, automated encrypted backup capabilities, and more.

This blueprint extension extends the current Health blueprint to:

**INGEST** data including Fast Healthcare Interoperability Resource (FHIR) data source

**STORE** sensitive and regulated health information (in both a Windows SQL2017 server, and Azure PaaS solution)

**ANALYZE** and predict outcomes (using an existing Machine Learning solution)

**INTERACT** with the results and predictions  (using an existing PowerBi solution)

**IDENTITY** management of solution (Azure Active Directory and role-based access control (RBAC))

**SECURITY** enabled features (Including Azure Security Center, Operations Management Suite (OMS), and Application Insights
)


![](images/design2.png)


# Deploying the solution overview

## Setting up a Privileged Access Workstation (PAW) ##

It is essential that before any deployment is started a known 'good clean client' is configured to connect to the cloud. This can be done in varied levels of security assurance. It is recommended that a **Privileged Access Workstation** be set up and all installation commands are executed from this machine using a machine administrator account.

Deploy a PAW solution to ensure that management of the services is done in a secure service model. This step is recommended to ensure access to subscription management occurs from a isolated client host.
Review [Privileged Access Workstation (PAW) for details.](https://docs.microsoft.com/en-us/windows-server/identity/securing-privileged-access/privileged-access-workstations)

## Setting up Pre-Requisites and enabling services ##

The Deploy the Health data and AI - Extension solution will require the configuration and set up including the configuration of a known good client install host, and service rights to deploy the components. This can be found in the script **deploy.ps1** with the **installModules** switch, used to install and verify all components are correctly set up of the [deployment guide](./deployment.md).

## Setting up the PaaS based health data and AI solution ##

Deploy the [Azure Security and Compliance Data and AI Health Blueprint](./deployment.md) which will install the core elements of the PaaS solution. This includes all of the platform-as-a-service (PaaS) environment for ingesting, storing, analyzing, and interacting with personal and non-personal medical records in a secure, multi-tier cloud environment, deployed as an end-to-end solution. It showcases a common reference architecture and is designed to simplify adoption of Microsoft Azure.
Details to the solution can be found at the [Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI](https://docs.microsoft.com/en-us/azure/security/blueprints/azure-health) resource.

## Deploy the IaaS lockdown configurations ##
In this step, use the deployIaaS.ps1 script found in the [Blueprint/Deployment](./Deployment) folder, to  Deploy the Health data and AI Extension. The script will enable the following capabilities
in three Phases:

### Phase 1:  Initial deployment and setup. ###
1.	Turns on Azure Security Center (ASC) auto-provisioning for all IaaS VMs in subscription.
2.	Sets up an Azure Active Directory application ID and service principal, for Key Vault authentication.
3.	Enables ASC and Operations Management Suite (OMS) monitoring at the resource group level (new APIs).
4.	Deploys latest SQL2017 instance running on Windows Server 2016.
5.	Sets up VM admin account using strong random password and username.
6.	Sets up VM with zero exposed inbound internet access, via network security group configuration.
7.	Configures OMS workspace elements for VM monitoring.
8.	Enables mandatory storage encryption and HTTPS usage for all storage accounts used. SQL backup and provisioning artifacts accounts use Virtual Network (VNET) firewall rules, and SAS token access for provisioning artifacts, to block access to these assets from unauthorized systems or from the internet.
9.	Configures two Azure Key Vault instances with Hardware Security Module (HSM) and soft-delete capability. One instance is used by SQL, and one instance is used by Azure Disk Encryption, using separate access policies.

### Phase 2:  Applying security policies and monitoring capabilities. ###
1.	Enables Azure disk encryption, using new deployment model that doesn’t require a dedicated Application ID and service principal provisioning.
2.	Enables and configures Microsoft Anti-malware.
3.	Enables Microsoft monitoring agent, for VM event log and security audit log collection and retention in an Azure storage account.
4.	Enables SQL IaaS extension: scheduled maintenance & patching window, Key Vault integration for Extensible Key Management (TDE), and automated encrypted backup support.
5.	Enables SQL AD based administration of existing PaaS database instance.
6.	Network security group and subnet access used to lockdown access between SQL IaaS VM and PaaS SQL instance.
7.	Uses managed service identity, for SQL IaaS VM -> SQL PaaS authentication.

### Phase 3: Deploying and executing payload to deployed VM. ###
1.	Custom script extension execution illustrates “lift and shift” of on-premise exported data to the SQL IaaS VM instance, without opening internet facing ports.
2.	Sample health data set is deployed to the IaaS VM and imported into the SQL instance.
3.	IaaS VM to PaaS SQL database query is issued, using Virtual Machine managed service identity authentication.  

NOTE - The VM will be isolated to an Azure VNet. To gain access to the IaaS VM, you will need to add a local inbound port rule to allow 3389 for Remote Desktop (RDP) connection to the VM
 address. The rule should be restricted to an appropriate range of source addresses. Additionally, the VM's password will need to be reset using the "password reset" functionality in the management portal.
 
 
 


![](images/ra2.png)

## INTERACT (Data visualization) using PowerBi reflects the last step of the demonstration. ##

The script moves 10,000 patient records to the SQL Server 2017 on the VM. This illustrates automated moving of data to a VM that was a result of a "Lift and Shift" operation, and subsequent interaction with a PaaS service in Azure.

It is essential the data ingestion process from the Health blueprint be run first, as the scripts in the extension build on the databse and content provided in the base blueprint.

View revised data in PowerBI (PowerBI dashboard will be updated)
The solution provides a simple Microsoft PowerBI visualization of the solution data. Microsoft PowerBI is required to open the sample report located at [Blueprint/Deployment/Reports](https://github.com/RajeevRangappa/Health-Data-and-AI-Blueprint/tree/master/Reports). Using the PowerBI free edition works for this demo but will not allow for reports to be shared. 


# Deploying the automation
 1. To deploy the solution, follow the instructions provided in the [deployment guidance](https://github.com/RajeevRangappa/Health-Data-and-AI-Blueprint/blob/master/deployment.md).



2. Frequently asked questions can be found in the [FAQ](https://github.com/RajeevRangappa/Health-Data-and-AI-Blueprint/blob/master/faq.md) guidance.

3. [Threat Model](https://github.com/RajeevRangappa/Health-Data-and-AI-Blueprint/tree/master/Files) A comprehensive threat model is provided in tm7 format for use with the [Microsoft Threat Modeling Tool](https://www.microsoft.com/en-us/download/details.aspx?id=49168), showing the components of the solution, the data flows between them, and the trust boundaries. The model can help customers understand the points of potential risk in the system infrastructure when developing Machine Learning Studio components or other modifications.

4. [Customer implementation matrix](https://github.com/RajeevRangappa/Health-Data-and-AI-Blueprint/tree/master/Files) A Microsoft Excel workbook lists the relevant HITRUST requirements and explains how Microsoft and the customer are responsible for meeting each one.


# Disclaimer


 The deployment script is designed to deploy the core elements of the Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI. The details of the solutions operation, and elements can be reviewed at aka.ms/healthcareblueprint
Copyright (c) Microsoft Corporation, and KenSci - All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.




