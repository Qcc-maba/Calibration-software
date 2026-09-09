<#
.SYNOPSIS
    Runs stage A of the portal deploy test plan against a running CustomerPortalApi.

.DESCRIPTION
    Phase A of the go-live is "the service is in production and correct, and no customer is
    exposed yet". This script is that phase's exit criterion, so it can be answered in one
    command instead of four hand-typed ones.

    It is READ-ONLY apart from one thing: with -RealEmail it asks the service to mail a real
    one-time code. That is a real e-mail to a real person, so it only happens when you pass the
    address explicitly.

    Run it ON MbaCustWeb after Install-CustomerPortalApi-Service.ps1, or from anywhere once the
    reverse proxy and DNS are up (-BaseUrl https://portal-api.qcc.co.il).

.PARAMETER BaseUrl
    Where the service answers. Default http://localhost:5312, which is what to use on the box
    itself before the proxy exists.

.PARAMETER ApiKey
    The CustomerPortal:ProxyApiKey value. Without it only the checks that need no key run, and
    the ones that do are reported as skipped rather than silently passing.

.PARAMETER RealEmail
    A genuine customer-contact address. Test A3 mails a code to it. Omit to skip that test.

.EXAMPLE
    .\Verify-PortalApi-Deploy.ps1
.EXAMPLE
    .\Verify-PortalApi-Deploy.ps1 -ApiKey '<the key>' -RealEmail 'someone@customer.co.il'
.EXAMPLE
    .\Verify-PortalApi-Deploy.ps1 -BaseUrl https://portal-api.qcc.co.il -ApiKey '<the key>'
#>
param(
    [string] $BaseUrl = 'http://localhost:5312',
    [string] $ApiKey,
    [string] $RealEmail
)

$ErrorActionPreference = 'Continue'
$BaseUrl = $BaseUrl.TrimEnd('/')

$results = @()
function Add-Result {
    param([string] $Id, [string] $What, [string] $Verdict, [string] $Detail)
    $script:results += [pscustomobject]@{ Id = $Id; What = $What; Verdict = $Verdict; Detail = $Detail }
    $colour = switch ($Verdict) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
    Write-Host ("  {0,-3} {1,-46} {2,-6} {3}" -f $Id, $What, $Verdict, $Detail) -ForegroundColor $colour
}

# Returns the HTTP status code, whatever it is. Invoke-RestMethod throws on 4xx/5xx, and a 401
# here is the expected answer rather than an error - so the status has to be read off the
# exception rather than allowed to abort the run.
function Invoke-Portal {
    param([string] $Path, [hashtable] $Headers, [string] $Body)
    try {
        $r = Invoke-WebRequest -Uri "$BaseUrl$Path" -Method Post -Headers $Headers `
                -ContentType 'application/json' -Body $Body -TimeoutSec 30 -UseBasicParsing
        return @{ Code = [int]$r.StatusCode; Body = $r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { return @{ Code = [int]$resp.StatusCode; Body = '' } }
        return @{ Code = -1; Body = $_.Exception.Message }
    }
}

Write-Host ''
Write-Host "=== Portal API - stage A verification against $BaseUrl ===" -ForegroundColor Cyan
Write-Host ''

# --- A1: the service answers and knows its own configuration --------------------------------
try {
    $health = Invoke-RestMethod "$BaseUrl/health" -TimeoutSec 20
    if ($health.database -eq 'configured' -and $health.smtp -eq 'configured') {
        Add-Result 'A1' '/health reports database and smtp configured' 'PASS' ''
    } else {
        Add-Result 'A1' '/health reports database and smtp configured' 'FAIL' `
            ("database=$($health.database) smtp=$($health.smtp)")
    }
} catch {
    Add-Result 'A1' '/health answers' 'FAIL' $_.Exception.Message
    Write-Host ''
    Write-Host 'The service is not answering. Nothing below can be trusted - stop here.' -ForegroundColor Red
    Write-Host 'Check: Get-Service MabaCustomerPortalApi, then Event Viewer > Application.' -ForegroundColor Red
    exit 1
}

$body = '{"email":"definitely-not-a-customer@example.invalid"}'

# --- A2: THE important one. An unauthenticated request must be refused ------------------------
# request-otp answers differently for a registered and an unregistered address, so an open
# service lets anyone walk a list of e-mails and learn which are MABA customers.
$noKey = Invoke-Portal -Path '/api/customer-auth/request-otp' -Headers @{} -Body $body
if ($noKey.Code -eq 401) {
    Add-Result 'A2' 'request-otp WITHOUT a key is refused (401)' 'PASS' ''
} else {
    Add-Result 'A2' 'request-otp WITHOUT a key is refused (401)' 'FAIL' "got $($noKey.Code)"
}

# --- A3/A4: with the key ----------------------------------------------------------------------
if (-not $ApiKey) {
    Add-Result 'A3' 'request-otp WITH the key is accepted' 'SKIP' 'pass -ApiKey to run this'
    Add-Result 'A4' 'an unknown address still answers 200' 'SKIP' 'pass -ApiKey to run this'
} else {
    $hdr = @{ 'X-Portal-Api-Key' = $ApiKey }

    # An address that is certainly not a customer. 200 with no mail is correct: the service must
    # not reveal which addresses it knows.
    $unknown = Invoke-Portal -Path '/api/customer-auth/request-otp' -Headers $hdr -Body $body
    if ($unknown.Code -eq 200) {
        Add-Result 'A4' 'an unknown address still answers 200' 'PASS' 'no mail sent, as designed'
    } else {
        Add-Result 'A4' 'an unknown address still answers 200' 'FAIL' "got $($unknown.Code)"
    }

    if ($RealEmail) {
        $real = Invoke-Portal -Path '/api/customer-auth/request-otp' -Headers $hdr `
                    -Body (@{ email = $RealEmail } | ConvertTo-Json -Compress)
        if ($real.Code -eq 200) {
            Add-Result 'A3' 'request-otp WITH the key is accepted' 'PASS' "check $RealEmail for the mail"
        } else {
            Add-Result 'A3' 'request-otp WITH the key is accepted' 'FAIL' "got $($real.Code)"
        }
    } else {
        Add-Result 'A3' 'request-otp WITH the key is accepted' 'SKIP' 'pass -RealEmail to send a real code'
    }
}

# --- Configuration that only bites later ------------------------------------------------------
$sessionSecret = [Environment]::GetEnvironmentVariable('CustomerPortal__SessionSecret', 'Machine')
$otpPepper     = [Environment]::GetEnvironmentVariable('CustomerPortal__OtpPepper', 'Machine')

if ($sessionSecret) {
    # The value must equal CUSTOMER_SESSION_SECRET on the Vercel side. This cannot check that from
    # here, so it checks the half it can see and reminds about the half it cannot.
    Add-Result 'C1' 'CustomerPortal__SessionSecret is set (machine)' 'PASS' `
        'must equal CUSTOMER_SESSION_SECRET in Vercel'
} else {
    Add-Result 'C1' 'CustomerPortal__SessionSecret is set (machine)' 'FAIL' `
        'unset - customers will log in and be thrown straight out'
}

if ($otpPepper) {
    Add-Result 'C2' 'CustomerPortal__OtpPepper is set (machine)' 'PASS' 'never change it once live'
} else {
    Add-Result 'C2' 'CustomerPortal__OtpPepper is set (machine)' 'FAIL' 'unset'
}

# --- Verdict -----------------------------------------------------------------------------------
Write-Host ''
$failed  = @($results | Where-Object Verdict -eq 'FAIL')
$skipped = @($results | Where-Object Verdict -eq 'SKIP')

if ($failed.Count -gt 0) {
    Write-Host "STAGE A FAILED - $($failed.Count) check(s):" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $($_.Id) $($_.What)  $($_.Detail)" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Do not connect portal.qcc.co.il until these pass.' -ForegroundColor Red
    exit 1
}

if ($skipped.Count -gt 0) {
    Write-Host "Stage A passed, but $($skipped.Count) check(s) were skipped:" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "  $($_.Id) $($_.What)  -  $($_.Detail)" -ForegroundColor Yellow }
    Write-Host ''
    Write-Host 'Re-run with -ApiKey and -RealEmail before calling stage A complete.' -ForegroundColor Yellow
    exit 0
}

Write-Host 'STAGE A PASSED. The service is correct in production.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next gate before portal.qcc.co.il: MBA-937, MBA-938, MBA-946.' -ForegroundColor Gray
Write-Host 'See docs/PORTAL-DEPLOY-RUNBOOK.md section 0.1.' -ForegroundColor Gray
