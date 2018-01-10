#
# lib.psm1
#
# Contains functions for healthcare operations
#

# Get Authentication token
function Get-AuthToken{
    param(
        [parameter(Mandatory=$true)]
        [string]$tenantId,
        [parameter(Mandatory=$true)]
        [string]$clientId,
        [parameter(Mandatory=$true)]
        [string]$clientSecret,
        [parameter(Mandatory=$true)]
        [string]$replyUrl
		)
	process{

		# Authorize
        $authorzationUrl = "https://login.microsoftonline.com/$tenantId/oauth2/authorize?response_type=code&client_id=$clientId&redirect_uri=$replyUrl&resource=$clientId"
        
        # Load UI
        # Fake a proper endpoint for the Redirect URI
        $code = LoginBrowser $authorzationUrl (New-Object system.uri($replyUrl))

		  # Access token
        $ClientSecret=[System.Web.HttpUtility]::UrlEncode($ClientSecret)
        $tokenRequestBody="client_id=$clientId&redirect_uri=$replyUrl&grant_type=authorization_code&client_secret=$ClientSecret&code=$code"
        $tokenResponse=Invoke-WebRequest -Method Post -Body $tokenRequestBody -Uri https://login.microsoftonline.com/common/oauth2/token
        $tokenData= ConvertFrom-Json -InputObject $tokenResponse
        $token=$tokenData.access_token

		return $token
	}
}

# Call Healthcare Functions
function Invoke-HealthcareFunction{
	param(
		[parameter(Mandatory=$true)]
		[string]$accessToken,
		[parameter(Mandatory=$true)]
		[validateset("Get","Post","Put")]
		[string]$httpMethod,
		[parameter(Mandatory=$true)]
		[string]$data,
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

# generate reandom alphabet string of specified length
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

# display browser window and navigate to authorize url
# for user login and obtain the authorization code after
# successful login
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

	# Create an Internet Explorer Window for the Login Experience
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
		# Grab URL in IE Window
        $urls = (New-Object -ComObject Shell.Application).Windows() | Where-Object {($_.LocationUrl -match "(^https?://.+)|(^ftp://)") -and ($_.HWND -eq $ie.HWND)} | Where-Object {$_.LocationUrl}

        foreach ($a in $urls)
        {
			# If URL is in the form we expect, with the Reply URL as the domain, and the code in the URL, grab the code
            if (($a.LocationUrl).Contains("?code="))
            {
                $code = ($a.LocationUrl)
                $code = ($code -replace (".*code=") -replace ("&.*"))
                
                $ie.Quit()
                break loop
            }
			# If we catch an error, output the error information
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
