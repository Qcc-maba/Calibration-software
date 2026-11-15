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
    # The account the server's updater reads the share as. QCCAnalyticsUpdate runs
    # as SYSTEM, which on the network is the computer account - and computer
    # accounts are not in Domain Users, so the parent's inherited grant does not
    # cover it. Without an explicit ACE for it the auto-deploy is dead (MBA-1032).
    [string] $ReaderAccount = 'MABA\MABA-DC2$',
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

$readRights = [Security.AccessControl.FileSystemRights]::ReadAndExecute
$sidType    = [Security.Principal.SecurityIdentifier]

# Does the ACL of $path let $sid read it? An ACL inspection, not a probe made as
# that account: it counts the account itself plus the groups every computer
# account is in, and fails on any deny. Good enough to catch the folder being
# recreated with inherited permissions only, which is the way this broke.
function Test-ReaderAcl($path, $sid) {
    $who = @($sid.Value, 'S-1-1-0', 'S-1-5-11')                    # self, Everyone, Authenticated Users
    if ($sid.AccountDomainSid) { $who += "$($sid.AccountDomainSid.Value)-515" }   # Domain Computers
    $allow = 0; $deny = 0
    foreach ($r in (Get-Item -LiteralPath $path -Force).GetAccessControl('Access').GetAccessRules($true, $true, $sidType)) {
        if ($who -notcontains $r.IdentityReference.Value) { continue }
        # InheritOnly rules do not apply to the object itself.
        if ($r.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) { continue }
        if ($r.AccessControlType -eq 'Allow') { $allow = $allow -bor [int]$r.FileSystemRights }
        else                                  { $deny  = $deny  -bor [int]$r.FileSystemRights }
    }
    (($allow -band [int]$readRights) -eq [int]$readRights) -and (($deny -band [int]$readRights) -eq 0)
}

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

    # The swap below replaces the folder, and a folder created fresh carries only
    # what it inherits from the parent: every explicit ACE on the old one is lost,
    # including the one the server's updater reads through. That is how the
    # 12 November publish silently disabled the auto-deploy (MBA-1032). So carry
    # the old folder's explicit ACEs over, and make sure the reader's is among
    # them - set on the empty staging folder, before anything is copied in, so
    # every file inherits it and the rename keeps it.
    try   { $readerSid = (New-Object Security.Principal.NTAccount($ReaderAccount)).Translate($sidType) }
    catch { throw "cannot resolve reader account '$ReaderAccount': $($_.Exception.Message)" }

    $carried = @()
    if (Test-Path $Share) {
        $carried = @((Get-Item $Share).GetAccessControl('Access').GetAccessRules($true, $false, $sidType))
    }
    $stagingItem = New-Item -ItemType Directory -Path $staging -Force
    $acl = $stagingItem.GetAccessControl('Access')
    foreach ($r in $carried) { $acl.AddAccessRule($r) }
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(
        $readerSid, $readRights, 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    $stagingItem.SetAccessControl($acl)
    Info ('permissions: {0} explicit ACE(s) carried over, {1} ReadAndExecute ensured' -f $carried.Count, $ReaderAccount)

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

    # Verify what was just published, on the folder and on the one file the
    # updater hashes. Failing here is the point: this check would have caught
    # the 12 November break on the spot instead of three days later.
    $unreadable = @($Share, (Join-Path $Share 'payload\dist\index.cjs')) |
        Where-Object { -not (Test-ReaderAcl $_ $readerSid) }
    if ($unreadable) {
        Write-Host ''
        Write-Host 'PUBLISHED, BUT THE SERVER CANNOT READ IT' -ForegroundColor Red
        $unreadable | ForEach-Object { Write-Host "  no read access for $ReaderAccount on $_" -ForegroundColor Red }
        Write-Host '  The automatic deploy will log ACCESS DENIED and install nothing.'
        Write-Host "  Fix: grant $ReaderAccount ReadAndExecute (ContainerInherit,ObjectInherit) on $Share"
        throw "published build is not readable by $ReaderAccount"
    }
    Info "verified: $ReaderAccount can read the folder and payload\dist\index.cjs"

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
