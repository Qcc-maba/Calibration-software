#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Instruction Assistant (Systems/InstructionAssistant) as a Windows Service.

.DESCRIPTION
    Publishes the net10 service, registers it with the SCM and starts it.

    Secrets are stored as MACHINE-scope environment variables, deliberately. A Windows Service
    runs under LocalSystem (or whichever account you pick) and therefore CANNOT see the
    User-scope variables of the person who developed it — ANTHROPIC_API_KEY set for your own
    account is invisible to the service, and the Priority connection string lives in
    appsettings.Development.json which is gitignored and not read in Production.

    Both values are only written when supplied, so re-running the script to upgrade the binaries
    leaves existing secrets untouched.

.PARAMETER AnthropicApiKey
    Claude API key. Defaults to your User-scope ANTHROPIC_API_KEY when omitted, so the common
    case needs no typing. Pass explicitly to change it.

.PARAMETER PriorityConnectionString
    Read-only connection string to the Priority company DB (amaba). Omit to keep the current one.

.PARAMETER Port
    TCP port the service listens on. Default 5311.

.EXAMPLE
    .\Install-InstructionAssistant-Service.ps1 -PriorityConnectionString "Server=maba-priority\pri;Database=amaba;User Id=kyulan;Password=***;TrustServerCertificate=True;Encrypt=False"

.EXAMPLE
    # Upgrade the binaries only; secrets already configured
    .\Install-InstructionAssistant-Service.ps1
#>
param(
    [string] $AnthropicApiKey,
    [string] $PriorityConnectionString,
    [int]    $Port = 5311
)

$ErrorActionPreference = 'Stop'

$ServiceName = 'MabaInstructionAssistant'
$DisplayName = 'Maba Instruction Assistant'
$Description = 'Summarizes the customer calibration instructions for an instrument (ECS workbook, network instruction files, Priority order text).'

# scripts\ lives directly under the repo root.
$Root       = Split-Path $PSScriptRoot -Parent
$Project    = Join-Path $Root 'Systems\InstructionAssistant\Maba.VCT.InstructionAssistant.csproj'
$PublishDir = Join-Path $Root 'Systems\InstructionAssistant\publish'
$BinaryPath = Join-Path $PublishDir 'Maba.VCT.InstructionAssistant.exe'

Write-Host '=== Maba Instruction Assistant - Service Installer ===' -ForegroundColor Cyan

if (-not (Test-Path $Project)) {
    Write-Error "Project not found at $Project"
    exit 1
}

# ── Stop first: the publish step cannot overwrite a running executable ────────────────────────
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host 'Stopping existing service...' -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 3
}

# ── Publish ──────────────────────────────────────────────────────────────────────────────────
Write-Host "Publishing to $PublishDir ..." -ForegroundColor Yellow
dotnet publish $Project -c Release -o $PublishDir --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed (exit $LASTEXITCODE)"; exit 1 }
if (-not (Test-Path $BinaryPath)) { Write-Error "Published executable not found at $BinaryPath"; exit 1 }
Write-Host "  Binary: $BinaryPath" -ForegroundColor Gray

# ── Machine-scope configuration ───────────────────────────────────────────────────────────────
function Set-MachineVar {
    param([string] $Name, [string] $Value, [switch] $Secret)
    if (-not $Value) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    $shown = if ($Secret) { '***' } else { $Value }
    Write-Host "  $Name = $shown" -ForegroundColor Gray
}

Write-Host 'Applying machine-scope configuration...' -ForegroundColor Yellow

if (-not $AnthropicApiKey) {
    $AnthropicApiKey = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User')
    if ($AnthropicApiKey) { Write-Host '  (using your User-scope ANTHROPIC_API_KEY)' -ForegroundColor DarkGray }
}

Set-MachineVar 'ANTHROPIC_API_KEY' $AnthropicApiKey -Secret
Set-MachineVar 'InstructionAssistant__Priority__ConnectionString' $PriorityConnectionString -Secret
Set-MachineVar 'ASPNETCORE_URLS' "http://localhost:$Port"

# Warn loudly rather than installing a service that silently answers without a summary.
$effectiveKey = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'Machine')
if (-not $effectiveKey) {
    Write-Host 'WARNING: no machine-scope ANTHROPIC_API_KEY - the service will return sources without an AI summary.' -ForegroundColor Yellow
}
$effectiveConn = [Environment]::GetEnvironmentVariable('InstructionAssistant__Priority__ConnectionString', 'Machine')
if (-not $effectiveConn) {
    Write-Host 'WARNING: no machine-scope Priority connection string - MABA-number lookup and order instructions will be unavailable.' -ForegroundColor Yellow
}

# ── (Re)register with the SCM ─────────────────────────────────────────────────────────────────
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
    Write-Host 'Check Event Viewer > Windows Logs > Application.' -ForegroundColor Yellow
    exit 1
}

# ── Prove it actually answers, not merely that the SCM started it ─────────────────────────────
Write-Host "Verifying http://localhost:$Port/health ..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod "http://localhost:$Port/health" -TimeoutSec 20
    Write-Host "Service '$ServiceName' is running." -ForegroundColor Green
    Write-Host "  sources          : $($health.sources -join ', ')" -ForegroundColor Gray
    Write-Host "  summarizer mode  : $($health.mode)" -ForegroundColor Gray
    Write-Host "  central Excel    : $(if ($health.centralExcelExists) { 'found' } else { 'NOT FOUND' })" -ForegroundColor Gray
    if (-not $health.centralExcelExists) {
        Write-Host 'WARNING: the central ECS workbook was not reachable. A service running as' -ForegroundColor Yellow
        Write-Host '         LocalSystem has no access to \\maba-dc - give the service a domain' -ForegroundColor Yellow
        Write-Host '         account with read access to the share (services.msc > Log On).' -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: the service is running but /health did not answer: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}
