<#
    Builds the app and publishes it to the shared folder the server pulls from.

        powershell -ExecutionPolicy Bypass -File .\local-scripts\Publish-ToServer.ps1

    That is the whole release process: once the auto-updater is installed on the
    server (Install-AutoUpdater.ps1, one time), publishing here is enough - the
    server compares hashes on its own schedule and upgrades itself, rolling back
    automatically if the new build fails its health check.

    The share holds one folder, always the current build. There is no version
    history on purpose: the server keeps its own dist_bak_* backups, which are
    the ones that matter for rolling back.

    Output is ASCII on purpose - Windows consoles render Hebrew as mojibake.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # UNC and not F:, which is a mapped drive: a drive letter belongs to one logon
    # session, so an elevated window - where a deploy is usually run - does not see
    # it at all and the publish dies on "share not reachable".
    [string] $Share = '\\maba-srv\maba2000\Eliran\qcc-latest',
    [switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$repo     = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
# The deployment scripts live in the repo, next to the code they deploy. They
# used to be read from a folder on the Desktop through a path built by walking
# parents, which resolved to the wrong place - and the copy loop skipped missing
# files silently, so a publish quietly shipped the payload with no scripts.
$template = Join-Path $repo 'deploy'

function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }

# ---------------------------------------------------------------- build
if (-not $SkipBuild) {
    Step 'Building'
    Push-Location $repo
    try {
        # Call npm.cmd through cmd.exe. "& npm run build" under PS 5.1 goes
        # through npm.ps1, which mangles the arguments - npm receives "pm" and
        # answers 'Unknown command: "pm"'.
        & cmd.exe /c 'npm run build'
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
    } finally { Pop-Location }
} else { Info 'skipped (-SkipBuild)' }

$dist = Join-Path $repo 'dist\index.cjs'
if (-not (Test-Path $dist)) { throw "no build at $dist" }
Info ('build: {0:N0} bytes, {1}' -f (Get-Item $dist).Length, (Get-Item $dist).LastWriteTime)

# ---------------------------------------------------------------- publish
Step "Publishing to $Share"
$parent = Split-Path -Parent $Share
if (-not (Test-Path $parent)) { throw "share not reachable: $parent" }

if ($PSCmdlet.ShouldProcess($Share, 'Replace published build')) {
    # Write to a staging folder and swap, so the server never reads a half-copied
    # build if its check happens to fire mid-publish.
    $staging = "$Share.new"
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $staging 'payload\data') -Force | Out-Null

    Copy-Item (Join-Path $repo 'dist')         (Join-Path $staging 'payload\dist')         -Recurse -Force
    Copy-Item (Join-Path $repo 'data\pricing') (Join-Path $staging 'payload\data\pricing') -Recurse -Force
    foreach ($f in 'env-additions.txt', 'README.md', 'check-pricing-export.mjs',
                   'Update-QCCAnalytics.ps1', 'Install-AutoUpdater.ps1',
                   'Install-QCCAnalytics.ps1', 'Rollback-QCCAnalytics.ps1') {
        $src = Join-Path $template $f
        if (-not (Test-Path $src)) { throw "missing deployment file: $src" }
        Copy-Item $src (Join-Path $staging $f) -Force
    }

    # The API key is injected here rather than kept in the repo. Without it the
    # published env-additions.txt would either leak the key into git or omit it.
    $envFile = Join-Path $repo '.env'
    if (Test-Path $envFile) {
        $m = [regex]::Match((Get-Content $envFile -Raw), '(?m)^\s*ANTHROPIC_API_KEY\s*=\s*(\S+)')
        if ($m.Success) { Add-Content (Join-Path $staging 'env-additions.txt') ("ANTHROPIC_API_KEY=" + $m.Groups[1].Value) }
    }
    $hash = (Get-FileHash (Join-Path $staging 'payload\dist\index.cjs') -Algorithm MD5).Hash
    Set-Content -Path (Join-Path $staging 'build.md5') -Value $hash -Encoding ascii

    if (Test-Path $Share) { Remove-Item $Share -Recurse -Force }
    Move-Item $staging $Share

    Write-Host ''
    Write-Host 'PUBLISHED' -ForegroundColor Green
    Write-Host "  $Share"
    Write-Host "  build md5: $hash"
    Write-Host ''
    Write-Host 'The server picks this up on its next check (daily, and at startup).'
    Write-Host 'To apply it right now, on the server as administrator:'
    Write-Host '  Start-ScheduledTask -TaskName QCCAnalyticsUpdate'
    Write-Host '  Get-Content C:\apps\qcc-updater\update.log -Tail 20'
}
