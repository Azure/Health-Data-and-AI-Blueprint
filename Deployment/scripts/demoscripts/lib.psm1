<#
.SYNOPSIS
This script is designed to provide the demo capabilities of the blueprint solution. The code located here is designed to help understand how you can securely upload a built data set, and import patient data for ML analysis and storage.

.DESCRIPTION

Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.EXAMPLE

Import-Module -Name <ModulePath>\lib.psm1

Imports module in the session.
#>

# Get Authentication token, Opening up a browser instance to prompt for user login and tokenising credentials.
function Get-AuthToken{
    param(
		
		#Azure AD Tenant Id.
        [parameter(Mandatory=$true)]
        [string]$tenantId,

		#Azure AD Application Client Id
        [parameter(Mandatory=$true)]
        [string]$clientId,

		#Azure AD Application Client Secret
        [parameter(Mandatory=$true)]
        [string]$clientSecret,

		#Azure AD Application Reply Url
        [parameter(Mandatory=$true)]
        [string]$replyUrl
		)
	process{

		# Microsoft login Authorize URL
        $authorzationUrl = "https://login.microsoftonline.com/$tenantId/oauth2/authorize?response_type=code&client_id=$clientId&redirect_uri=$replyUrl&resource=$clientId"
        
        # Login browser 
        $code = LoginBrowser $authorzationUrl (New-Object system.uri($replyUrl))

		# User OAuth token retrieval.
        $ClientSecret=[System.Web.HttpUtility]::UrlEncode($ClientSecret)
        $tokenRequestBody="client_id=$clientId&redirect_uri=$replyUrl&grant_type=authorization_code&client_secret=$ClientSecret&code=$code"
        $tokenResponse=Invoke-WebRequest -Method Post -Body $tokenRequestBody -Uri https://login.microsoftonline.com/common/oauth2/token
        $tokenData= ConvertFrom-Json -InputObject $tokenResponse
        $token=$tokenData.access_token

		return $token
	}
}

<#
.Description 
The following function will call the custom Invoke-Healthcare funciton which is designed to authenticate an azure application for data processing.
The function will return status on successful and failed transactions.
#>
function Invoke-HealthcareFunction{
	param(
		#user access token
		[parameter(Mandatory=$true)]
		[string]$accessToken,
		#http method as per azure function need
		[parameter(Mandatory=$true)]
		[validateset("Get","Post","Put")]
		[string]$httpMethod,
		#input for post/put request data
		[parameter(Mandatory=$true)]
		[string]$data,

		#function endpoint url
		[parameter(Mandatory=$true)]
		[string]$functionUrl
	)

	process{
		
        # Function Http Call
        $headers = @{ 
            "Authorization" = ("Bearer {0}" -f $accessToken);
            "Content-Type" = "application/json";
        }
       
		$today= [DateTime]::Now.ToString("yyyy-MM-ddThh:mm:sszzz")
        Write-Host "sending request $today ..." -ForegroundColor Cyan
		try{
		
			$output = Invoke-WebRequest -Method $httpMethod -Headers $headers -Body $data -Uri $functionUrl
			$output = ConvertFrom-Json -InputObject $output
			Write-Host -ForegroundColor Green "response: "$output
			Write-Host '-----------------------------------------------------------------------------------------------------------------'
			return $output
		}
		catch{
			Write-Host "error : $_" -ForegroundColor Red
			Write-Host '-----------------------------------------------------------------------------------------------------------------'
			return @{'result'='failed'}
		}
	}
}

# Generates random string based on specified length
function Get-RandomName{
	param(
		[parameter(Mandatory=$true)]
		[int]$length
	)

	process{
		$randomName = -join ((65..90) + (97..122) | Get-Random -Count $length | % {[char]$_})
		return $randomName
	}
}

#Generates random integer based on minimum and maximum input provided.
function Get-RandomEncounterId{
	param(
		[parameter(Mandatory=$true)]
		[int]$minimum,
		[parameter(Mandatory=$true)]
		[int]$maximum
	)
	process{
		$encounterId = Get-Random -Minimum $minimum -Maximum $maximum
		return $encounterId
	}
}

# Display browser window and navigate to authorized url for user login and obtain the authorization code after successful login.
function LoginBrowser
{
    param
    (
        [Parameter(HelpMessage='Authorization URL')]
        [ValidateNotNull()]
        [string]$authorizationUrl,
        
        [Parameter(HelpMessage='Redirect URI')]
        [ValidateNotNull()]
        [uri]$redirectUri
    )

    $outputAuth = ".\Code.txt"

	# Create an browser dialog box for the login.
    $ie = New-Object -ComObject InternetExplorer.Application
    $ie.Width = 600
    $ie.Height = 500
    $ie.AddressBar = $false
    $ie.ToolBar = $false
    $ie.StatusBar = $false
    $ie.visible = $true
    $ie.navigate($authorizationUrl)

    while ($ie.Busy) {} 

    :loop while($true)
    {   
		# Retrieve URL in login dialog box
        $urls = (New-Object -ComObject Shell.Application).Windows() | Where-Object {($_.LocationUrl -match "(^https?://.+)|(^ftp://)") -and ($_.HWND -eq $ie.HWND)} | Where-Object {$_.LocationUrl}

        foreach ($a in $urls)
        {
			# Verifies the reply url which contains '?code=' and retrieve the authorisation code.
            if (($a.LocationUrl).Contains("?code="))
            {
                $code = ($a.LocationUrl)
                $code = ($code -replace (".*code=") -replace ("&.*"))
                
                $ie.Quit()
                break loop
            }
			# If url reverts '?error=', catch it as an error.
			elseif (($a.LocationUrl).StartsWith($redirectUri.ToString()+"?error="))
            {
                $error = [System.Web.HttpUtility]::UrlDecode(($a.LocationUrl) -replace (".*error="))
                $error | Write-Host
                break loop
            }
        }
    }

	# Return the Auth Code
    return $code
}
