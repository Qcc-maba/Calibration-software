#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Customer Portal API (Systems/CustomerPortalApi) as a Windows Service.

.DESCRIPTION
    Publishes the net10 service, registers it with the SCM and starts it.

    This service owns the customer portal login: it generates the one-time code, checks it against
    the Calibrator database and sends the mail. The web app on Vercel does none of that - it
    proxies to here (src/server/auth/customer-portal-api.ts), which is why the app's
    CUSTOMER_PORTAL_API_URL must point at an address Vercel can actually reach.

    Secrets are stored as MACHINE-scope environment variables. A service cannot see the User-scope
    variables of whoever installed it, and appsettings.Development.json is gitignored and not read
    in Production. Values are only written when supplied, so re-running to upgrade the binaries
    leaves existing secrets untouched.

.PARAMETER Bind
    "localhost" (default) - reachable only from this machine.
    "any"                 - binds every interface so a reverse proxy in front (portal.qcc.co.il)
                            can forward to it. REQUIRES -ProxyApiKey.

.PARAMETER ProxyApiKey
    Shared secret the web app must send in the X-Portal-Api-Key header. Mandatory for -Bind any,
    and the service itself refuses to start without it on a public binding (Auth/ExposureGuard.cs).
    The reason is specific, not generic hygiene: /api/customer-auth/request-otp answers differently
    for a registered and an unregistered address, so an open service is a customer-list oracle.

.PARAMETER ConnectionString
    Calibrator database. Omit to keep the current one.

.PARAMETER SmtpUser
    Microsoft 365 mailbox the codes are sent from.

.PARAMETER SmtpPassword
    Password for that mailbox.

.PARAMETER SmtpFrom
    Envelope sender. Must equal SmtpUser - M365 rejects a different one as spoofing. The display
    name is separate configuration (CustomerPortal:Smtp:FromDisplayName).

.PARAMETER Port
    TCP port. Default 5312.

.EXAMPLE
    .\Install-CustomerPortalApi-Service.ps1 -ConnectionString "Server=...;Database=Calibrator;..." -SmtpUser zimun@mba.co.il -SmtpPassword *** -SmtpFrom zimun@mba.co.il

.EXAMPLE
    .\Install-CustomerPortalApi-Service.ps1 -Bind any -ProxyApiKey (New-Guid).Guid
#>
param(
    [ValidateSet('localhost', 'any')]
    [string] $Bind = 'localhost',
    [string] $ProxyApiKey,
    [string] $ConnectionString,
    [string] $SmtpUser,
    [string] $SmtpPassword,
    [string] $SmtpFrom,
    [int]    $Port = 5312
)

$ErrorActionPreference = 'Stop'

$ServiceName = 'MabaCustomerPortalApi'
$DisplayName = 'Maba Customer Portal API'
$Description = 'One-time-code login for the customer portal: issues and verifies codes, and sends them by e-mail.'

$Root       = Split-Path $PSScriptRoot -Parent
$Project    = Join-Path $Root 'Systems\CustomerPortalApi\Maba.VCT.CustomerPortalApi.csproj'
$PublishDir = Join-Path $Root 'Systems\CustomerPortalApi\publish'
$BinaryPath = Join-Path $PublishDir 'Maba.VCT.CustomerPortalApi.exe'

Write-Host '=== Maba Customer Portal API - Service Installer ===' -ForegroundColor Cyan

if (-not (Test-Path $Project)) { Write-Error "Project not found at $Project"; exit 1 }

# Refuse before doing any work, not after publishing.
if ($Bind -eq 'any' -and -not $ProxyApiKey) {
    $existingKey = [Environment]::GetEnvironmentVariable('CustomerPortal__ProxyApiKey', 'Machine')
    if (-not $existingKey) {
        Write-Host 'ERROR: -Bind any exposes the login API with no shared secret.' -ForegroundColor Red
        Write-Host '       request-otp answers differently for known and unknown addresses, so an' -ForegroundColor Red
        Write-Host '       open service lets anyone enumerate your customer list.' -ForegroundColor Red
        Write-Host '       Pass -ProxyApiKey (New-Guid).Guid' -ForegroundColor Red
        exit 1
    }
    Write-Host '  (reusing the ProxyApiKey already configured on this machine)' -ForegroundColor DarkGray
}

# A running instance locks the executable the publish step wants to overwrite.
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host 'Stopping existing service...' -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 3
}
Get-Process -Name 'Maba.VCT.CustomerPortalApi' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  stopping stray console instance (pid $($_.Id))" -ForegroundColor DarkGray
    Stop-Process -Id $_.Id -Force
}

Write-Host "Publishing to $PublishDir ..." -ForegroundColor Yellow
dotnet publish $Project -c Release -o $PublishDir --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed (exit $LASTEXITCODE)"; exit 1 }
if (-not (Test-Path $BinaryPath)) { Write-Error "Published executable not found at $BinaryPath"; exit 1 }

function Set-MachineVar {
    param([string] $Name, [string] $Value, [switch] $Secret)
    if (-not $Value) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    $shown = if ($Secret) { '***' } else { $Value }
    Write-Host "  $Name = $shown" -ForegroundColor Gray
}

Write-Host 'Applying machine-scope configuration...' -ForegroundColor Yellow

if ($SmtpFrom -and $SmtpUser -and $SmtpFrom -ne $SmtpUser) {
    Write-Host "WARNING: SmtpFrom ($SmtpFrom) differs from SmtpUser ($SmtpUser)." -ForegroundColor Yellow
    Write-Host '         Microsoft 365 will reject the message as a spoofed sender.' -ForegroundColor Yellow
}

Set-MachineVar 'CustomerPortal__ProxyApiKey'      $ProxyApiKey      -Secret
Set-MachineVar 'CustomerPortal__ConnectionString' $ConnectionString -Secret
Set-MachineVar 'CustomerPortal__Smtp__User'       $SmtpUser
Set-MachineVar 'CustomerPortal__Smtp__Password'   $SmtpPassword     -Secret
Set-MachineVar 'CustomerPortal__Smtp__From'       $SmtpFrom

$listenHost = if ($Bind -eq 'any') { '0.0.0.0' } else { 'localhost' }
Set-MachineVar 'ASPNETCORE_URLS' "http://${listenHost}:$Port"
Set-MachineVar 'ASPNETCORE_ENVIRONMENT' 'Production'

$FirewallRule = 'Maba Customer Portal API'
Get-NetFirewallRule -DisplayName $FirewallRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
if ($Bind -eq 'any') {
    New-NetFirewallRule -DisplayName $FirewallRule -Direction Inbound -Protocol TCP `
        -LocalPort $Port -Action Allow -Profile Domain, Private | Out-Null
    Write-Host "  firewall: inbound TCP $Port allowed (Domain, Private)" -ForegroundColor Gray
} else {
    Write-Host '  firewall: no inbound rule (localhost only)' -ForegroundColor Gray
}

if (-not [Environment]::GetEnvironmentVariable('CustomerPortal__ConnectionString', 'Machine')) {
    Write-Host 'WARNING: no connection string - the service cannot look up contacts and every login will fail.' -ForegroundColor Yellow
}
if (-not [Environment]::GetEnvironmentVariable('CustomerPortal__Smtp__User', 'Machine')) {
    Write-Host 'WARNING: no SMTP user - codes cannot be sent.' -ForegroundColor Yellow
}

if ($svc) {
    Write-Host 'Removing existing service registration...' -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

Write-Host "Creating Windows Service '$ServiceName'..." -ForegroundColor Yellow
sc.exe create $ServiceName binPath= "`"$BinaryPath`"" start= auto DisplayName= "$DisplayName" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Failed to create service (exit $LASTEXITCODE)" -ForegroundColor Red; exit 1 }

sc.exe description $ServiceName $Description | Out-Null
# Restart on failure: 1st and 2nd after 30s, subsequent after 60s; counter resets daily.
sc.exe failure $ServiceName reset= 86400 actions= restart/30000/restart/30000/restart/60000 | Out-Null

Write-Host 'Starting service...' -ForegroundColor Yellow
Start-Service -Name $ServiceName
Start-Sleep -Seconds 5

$svc = Get-Service -Name $ServiceName
if ($svc.Status -ne 'Running') {
    Write-Host "WARNING: service installed but status is: $($svc.Status)" -ForegroundColor Yellow
    Write-Host 'The service deliberately refuses to start when it binds publicly with no ProxyApiKey.' -ForegroundColor Yellow
    Write-Host 'Check Event Viewer > Windows Logs > Application.' -ForegroundColor Yellow
    exit 1
}

Write-Host "Verifying http://localhost:$Port/health ..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod "http://localhost:$Port/health" -TimeoutSec 20
    Write-Host "Service '$ServiceName' is running." -ForegroundColor Green
    $health | Format-List | Out-String | Write-Host

    if ($Bind -eq 'any') {
        Write-Host 'Still to do OUTSIDE this script, for portal.qcc.co.il:' -ForegroundColor Cyan
        Write-Host "  1. Point portal.qcc.co.il at this site and forward to this machine:$Port." -ForegroundColor Gray
        Write-Host '  2. Terminate TLS there - this service speaks plain HTTP.' -ForegroundColor Gray
        Write-Host '  3. In Vercel set CUSTOMER_PORTAL_API_URL=https://portal.qcc.co.il plus the' -ForegroundColor Gray
        Write-Host '     matching X-Portal-Api-Key, then redeploy.' -ForegroundColor Gray
        Write-Host '  4. Set CustomerPortal:SecureCookies=true once it is served over HTTPS.' -ForegroundColor Gray
    }
} catch {
    Write-Host "WARNING: the service is running but /health did not answer: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}
