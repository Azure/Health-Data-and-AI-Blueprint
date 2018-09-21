## Code fragment pointers and more information

##Azure Security Center:
1.	REST API auto-provisioning enablement is found in deployIaaS.ps1:
$asc_uri = https://$asc_url/subscriptions/$asc_subscriptionId/providers/microsoft.Security/AutoProvisioningSettings/default?api-version=2017-08-01-preview
2.	OMS configuration, see WindowsSqlVirtualMachine.json, "Microsoft.OperationalInsights/workspaces”

##Azure Key Vault:
1.	Two separate key vaults are created, one to support Azure Disk Encryption, one to support SQL TDE.  Separate vaults ensure least privileged access with separate access policies.  See WindowsSqlVirtualMachine.json.
2.	PurgeProtection, and SoftDelete policies, which helps prevent accidental deletion or availability issues of keyvaults, are enabled on both keyvaults, see WindowsSqlVirtualMachine.json:
        "enableSoftDelete": true, "enablePurgeProtection": true
3.	Both keyvaults are configured to use hardware security modules (HSM), see WindowsSqlVirtualMachine.json:
        "sku": { "name": "premium" }
4.	Log data is collected and retained for both keyvaults, see WindowsSqlVirtualMachine.json:
Microsoft.KeyVault/vaults/providers/diagnosticsettings
Azure Storage account configuration, see WindowsSqlVirtualMachine.json, “Microsoft.Storage/storageAccounts”:
1.	Require SSL/TLS on storage endpoint:
"supportsHttpsTrafficOnly": true,
2.	Require server side encryption:
        "encryption": { "services": {  "blob": {  "enabled": true }  }
3.	Vnet/subnet firewall configuration for storage account:
       "networkAcls": {…
Anti-malware configuration for SQL IaaS VM, see WindowsSqlVirtualMachine.json, "name": "[concat(parameters('vmName'), '/IaaSAntimalware')]”
Microsoft monitoring agent configuration, used to support analytics and Azure Security Center, see WindowsSqlVirtualMachine.json,"[concat(parameters('vmName'),'/MicrosoftMonitoringAgent')]"
Managed Service identity extension configuration, which is recently considered optional, see WindowsSqlVirtualMachine.json, “[concat(parameters('vmName'),'/ManagedIdentityExtensionForWindows')]"
Diagnostic extension agent configuration, used to support log collection, including audit and diagnostic logs, see WindowsSqlVirtualMachine.json, "Microsoft.Insights.VMDiagnosticsSettings".
1.	The referenced xmlcfg variable includes various log collection settings, such as security audit log collection: <DataSource name=\"Security!*[System[(band(Keywords,13510798882111488))]]\" />

## SQL IaaS extension agent configuration, see WindowsSqlVirtualMachine.json, "name": "[concat(parameters('vmName'), '/SqlIaasExtension')]":
1.	"AutoPatchingSettings" for patch/update management.
2.	"AutoBackupSettings", as well as storage account and access key settings.
3.	"AutoTelemetrySettings"
4.	See PshFunctionsIaaS.ps1 for Azure Key Vault SQL TDE IaaS extension agent configuration.

## Azure disk encryption agent configuration settings, see WindowsSqlVirtualMachine.json, "name": "[concat(parameters('vmName'),'/AzureDiskEncryption')]"

Virtual network configuration to support access within application boundary, see WindowsSqlVirtualMachine.json, “Microsoft.Network/virtualNetworks”, “Microsoft.Network/networkInterfaces”, and “Microsoft.Network/networkSecurityGroups”

## Managed service identity configuration, see WindowsSqlVirtualMachine.json, reference to "type": "Microsoft.Compute/virtualMachines",  "identity": {  "type": "systemAssigned"  }
1.	Managed service identity used for SQL TDE configuration, authenticated access to Key vault.
2.	Managed service identity used by SQL IaaS instance, for authenticated access to PaaS SQL instance.

## CustomScriptExtension IaaS extension operation.  This extension facilitates execution of configuration and import of SQL payload for the IaaS VM.  See WindowsSqlVirtualMachinePayload.json.
1.	Execution parameters are passed from the template deployment parameters to the powershell command line.
2.	Execution artifacts are stored in a temporary storage account, referenced by short-lived read-only access facilitated by SAS token URI usage.

## Temporary storage account for uploaded VM artifacts.  This involves preparing the storage account and uploaded artifacts for usage by the CustomScriptExtension referenced above.  See PshFunctionsIaaS.ps1: TransferExecute-PayloadFunction().
1.	Storage account is created, which requires TLS/SSL, and configures encryption.
2.	VNet security is applied to storage account to limit access to systems in the sample Vnet/Subnet.
3.	The contents of the local artifact directory are combined into a zip file, and uploaded to the storage account.
4.	A short lived, read-only access SAS token URI is passed to the CustomScriptExtension.  See DeployIaaS.ps1, reference to New-AzureStorageContainerSASToken
