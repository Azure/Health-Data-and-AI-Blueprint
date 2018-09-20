<#
.SYNOPSIS
    Routines to support Logon and Impersonation.
#>

function Get-LogonLibrary
{
    if ($script:LogonLibrary)
    {
        return $script:LogonLibrary
    }

    $sig = @'
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

        [DllImport("kernel32.dll")]
        public static extern Boolean CloseHandle(IntPtr hObject);
'@
  
    $script:LogonLibrary = Add-Type -PassThru  -Name 'LogonLibrary' -MemberDefinition $sig

    return $script:LogonLibrary
}

function LogonUser([string]$UserName, [string]$Domain, [string]$Password)
{
##define 	LOGON32_LOGON_NETWORK_CLEARTEXT		8
##define 	LOGON32_LOGON_NEW_CREDENTIALS		9

    $LogonLibrary = Get-LogonLibrary

    [IntPtr]$hToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token

    $fSuccess = $LogonLibrary::LogonUser($UserName, $Domain, $Password, 8, 0, [ref]$hToken)
    if($fSuccess) {
        return $hToken, $fSuccess
    } 

    return $null, $fSuccess
}

function ImpersonateLoggedOnUser([IntPtr] $hToken)
{
   $Identity = New-Object Security.Principal.WindowsIdentity $hToken
   $IdentityContext = $Identity.Impersonate()
   $IdentityContext
}

function CloseHandle([IntPtr] $hObject)
{
    $LogonLibrary = Get-LogonLibrary
    $LogonLibrary::CloseHandle($hObject)
}
