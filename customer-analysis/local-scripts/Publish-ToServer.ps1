<#
    Builds the app and publishes it to the shared folder the server pulls from.

        powershell -ExecutionPolicy Bypass -File .\local-scripts\Publish-ToServer.ps1

    That is the whole release process: once the auto-updater is installed on the
    server (Install-AutoUpdater.ps1, one time), publishing here is enough - the
    server compares hashes on its own schedule and upgrades itself, rolling back
    automatically if the new build fails its health check.

    The share holds one folder, always the current build. There is no version
    history on purpose: the server keeps its own dist_bak_* backups, which are
    the ones that matter for rolling back. A qcc-latest.new or qcc-latest.old-*
    beside it is a publish in progress, or one that failed - see the swap below.

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

# Check the ACL on the folder and on the one file the updater hashes. Failing
# here is the point: this check would have caught the 12 November break on the
# spot instead of three days later. It reads NTFS ACLs only - share-level
# permissions and the server's own view are not covered; the end-to-end proof
# is the updater's next run (see the message at the end).
function Assert-Readable($folder, $when) {
    $unreadable = @($folder, (Join-Path $folder 'payload\dist\index.cjs')) |
        Where-Object { -not (Test-ReaderAcl $_ $readerSid) }
    if (-not $unreadable) { return }
    Write-Host ''
    Write-Host "$when, THE SERVER WOULD NOT BE ABLE TO READ IT" -ForegroundColor Red
    $unreadable | ForEach-Object { Write-Host "  no read grant for $ReaderAccount in the ACL of $_" -ForegroundColor Red }
    Write-Host '  The automatic deploy would log ACCESS DENIED and install nothing.'
    Write-Host "  Fix: grant $ReaderAccount ReadAndExecute (ContainerInherit,ObjectInherit) on $Share"
    throw "build at $folder is not readable by $ReaderAccount"
}

# Is $folder a complete build? Returns $null when it is, or the reason it is
# not. build.md5 is written last, so a folder whose md5 matches its
# payload\dist\index.cjs was fully copied - and reading both proves this
# account can read them.
function Get-BuildProblem($folder) {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return 'folder does not exist' }
    $md5File = Join-Path $folder 'build.md5'
    $main    = Join-Path $folder 'payload\dist\index.cjs'
    if (-not (Test-Path -LiteralPath $md5File)) { return 'no build.md5' }
    if (-not (Test-Path -LiteralPath $main))    { return 'no payload\dist\index.cjs' }
    try {
        $want = (Get-Content -LiteralPath $md5File -Raw).Trim()
        $have = (Get-FileHash -LiteralPath $main -Algorithm MD5).Hash
    } catch { return "cannot read it: $($_.Exception.Message)" }
    if ($want -ne $have) { return "build.md5 says $want, payload\dist\index.cjs hashes to $have" }
    $null
}

# Over SMB a rename can fail for a moment while something - the server's
# updater, Explorer, a listing still tearing down - holds a handle: "Access is
# denied" with ItemExistsUnauthorizedAccessError, gone a second later. That is
# what deleted the share on 15 November (MBA-1033), and a manual retry worked at
# once. So retry.
# A plain rename, not Move-Item: when Move-Item fails on a folder it can leave
# an empty folder behind at the destination (seen while testing MBA-1033 with a
# file held open), and an empty qcc-latest would block both the retry and the
# put-back of the previous build. Directory.Move either renames or does nothing.
# It never moves onto an existing folder either, where Move-Item would nest.
# Over SMB a rename can also take effect on the server and still report an
# error to the client. So after any failure, look at the disk: source gone and
# destination there means the rename happened, and that is a success.
# Only the transient kinds (access denied, sharing violation) are retried; a
# missing source or a bad path will not clear and surfaces at once, with its
# original exception.
function Move-WithRetry($from, $to, [int] $attempts = 5, [int] $pauseSeconds = 2) {
    for ($i = 1; ; $i++) {
        if (Test-Path -LiteralPath $to) {
            if (-not (Test-Path -LiteralPath $from)) { return }      # an earlier attempt did it
            throw "cannot move $from to $to - $to already exists"
        }
        try { [IO.Directory]::Move($from, $to); return }
        catch {
            $ex = $_.Exception
            if ($ex -is [Management.Automation.MethodInvocationException] -and $ex.InnerException) { $ex = $ex.InnerException }
            if ((Test-Path -LiteralPath $to) -and -not (Test-Path -LiteralPath $from)) { return }
            $transient = ($ex -is [UnauthorizedAccessException]) -or
                         ($ex -is [IO.IOException] -and -not ($ex -is [IO.DirectoryNotFoundException]) -and
                                                        -not ($ex -is [IO.FileNotFoundException]))
            if (-not $transient -or $i -ge $attempts) { throw $ex }
            Info ("move {0} -> {1} failed (attempt {2} of {3}): {4} - retrying in {5}s" -f
                  $from, $to, $i, $attempts, $ex.Message, $pauseSeconds)
            Start-Sleep -Seconds $pauseSeconds
        }
    }
}

# Best effort: a delete that fails leaves a folder the server never reads. An
# .old- folder is removed by the next successful publish; a staging folder makes
# the next publish refuse to start until someone looks at it and deletes it.
# Every build folder holds env-additions.txt with the injected API key, so a
# folder that will not go away at least loses that file, and the warning says
# when it could not.
function Remove-Leftover($path) {
    for ($i = 1; $i -le 3; $i++) {
        try { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop; return $true }
        catch { if ($i -lt 3) { Start-Sleep -Seconds 2 } }
    }
    if (-not (Test-Path -LiteralPath $path)) { return $true }
    $next = if ($path -eq $staging) { 'the next publish refuses to start until it is deleted by hand' }
            else { 'the next successful publish removes it' }
    Write-Host "    WARNING: could not delete $path - $next" -ForegroundColor Yellow
    $keyFile = Join-Path $path 'env-additions.txt'
    if (Test-Path -LiteralPath $keyFile) {
        try   { Remove-Item -LiteralPath $keyFile -Force -ErrorAction Stop; Write-Host '    (its env-additions.txt, which holds the API key, was deleted)' -ForegroundColor Yellow }
        catch { Write-Host "    It still holds env-additions.txt WITH THE ANTHROPIC API KEY - delete it by hand." -ForegroundColor Red }
    }
    $false
}

function Fail($headline, [string[]] $lines) {
    Write-Host ''
    Write-Host $headline -ForegroundColor Red
    $lines | ForEach-Object { Write-Host "  $_" }
    throw $headline
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
# Absolute, because the swap renames through .NET, which resolves a relative
# path against the process directory rather than the PowerShell location.
$Share  = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Share).TrimEnd('\')
Step "Publishing to $Share"
$parent = Split-Path -Parent $Share
if (-not (Test-Path $parent)) { throw "share not reachable: $parent" }

if ($PSCmdlet.ShouldProcess($Share, 'Replace published build')) {
    # Write to a staging folder and swap, so the server never reads a half-copied
    # build if its check happens to fire mid-publish. The swap moves the live
    # folder aside to <share>.old-<timestamp> and deletes it only once the new
    # one is in place and verified, so at every step there is a build at $Share
    # or a complete one beside it - never nothing (MBA-1033).
    $staging    = "$Share.new"
    $oldPattern = (Split-Path -Leaf $Share) + '.old-*'

    try   { $readerSid = (New-Object Security.Principal.NTAccount($ReaderAccount)).Translate($sidType) }
    catch { throw "cannot resolve reader account '$ReaderAccount': $($_.Exception.Message)" }

    # ------------------------------------------- leftovers of a failed publish
    # A staging folder or an .old- folder at this point means an earlier
    # publish did not finish. They may hold the only copy of a build - after the
    # 15 November failure the staging folder did - so they are never deleted
    # here: recover from them, or refuse and say why.
    # A listing that fails must not read as "no leftovers": with the share
    # missing, that would skip the only good build.
    try {
        $leftOld = @(Get-ChildItem -LiteralPath $parent -Directory -Filter $oldPattern -ErrorAction Stop |
                     Sort-Object Name -Descending | ForEach-Object { $_.FullName })
    } catch {
        Fail 'NOT PUBLISHED: CANNOT LOOK FOR LEFTOVERS OF AN EARLIER PUBLISH' @(
            "listing $parent failed: $($_.Exception.Message)"
            'Nothing was changed. Run this again.')
    }
    $leaf = Split-Path -Leaf $Share
    if (-not (Test-Path -LiteralPath $Share)) {
        # Restore the newest complete build: the staging folder first (it is
        # newer), else the newest complete .old-. An incomplete staging folder
        # does not stop the share from being restored - it only stops the publish.
        $source = $null; $stagingProblem = $null
        if (Test-Path -LiteralPath $staging) {
            $stagingProblem = Get-BuildProblem $staging
            if (-not $stagingProblem) { $source = $staging }
        }
        if (-not $source) {
            foreach ($o in $leftOld) { if (-not (Get-BuildProblem $o)) { $source = $o; break } }
        }
        if ($source) {
            Write-Host ''
            Write-Host 'RECOVERING FROM AN EARLIER FAILED PUBLISH' -ForegroundColor Yellow
            Write-Host "  $Share was missing. Putting back the complete build left in"
            Write-Host "  $source"
            Write-Host '  first, so the share is never empty while this publish runs.'
            try { Move-WithRetry $source $Share }
            catch {
                Fail "COULD NOT RECOVER: THE SHARE IS STILL MISSING: $Share" @(
                    "error: $($_.Exception.Message)"
                    "Nothing was deleted; the build is intact at $source."
                    "Run this again, or put it back by hand:  Rename-Item '$source' '$leaf'")
            }
            Info ("recovered: $Share, build md5 " + (Get-Content -LiteralPath (Join-Path $Share 'build.md5') -Raw).Trim())
            $leftOld = @($leftOld | Where-Object { $_ -ne $source })
            # The restored build is live now, so check it the way a published one
            # is checked. Warn rather than stop: the publish below ensures the
            # reader's grant on the new build, which is the fix.
            $unreadable = @($Share, (Join-Path $Share 'payload\dist\index.cjs')) | Where-Object { -not (Test-ReaderAcl $_ $readerSid) }
            if ($unreadable) {
                Write-Host "  WARNING: the restored build is live, but $ReaderAccount has no read grant on $($unreadable -join ', ')." -ForegroundColor Red
                Write-Host '  The publish below fixes that with the new build. If it fails, grant it by hand:'
                Write-Host "  $ReaderAccount ReadAndExecute (ContainerInherit,ObjectInherit) on $Share"
            } else { Info "restored build is readable by $ReaderAccount (ACL)" }
        }
        if ($stagingProblem) {
            $state = if ($source) { "$Share was missing and has been restored from $source - it is live." }
                     else         { "$Share is missing, and there is no complete build left to restore it from." }
            Fail 'REFUSING TO PUBLISH: THE LEFTOVER STAGING FOLDER IS INCOMPLETE' @(
                $state
                "$staging - left by an earlier publish that did not finish - is not a"
                "complete build: $stagingProblem. It was not deleted."
                "Look at it by hand; if it is rubbish, delete $staging and run this again.")
        }
        if (-not $source -and $leftOld) {
            Info "$Share is missing and the leftover folder(s) are not complete builds - publishing fresh"
        }
    } elseif (Test-Path -LiteralPath $staging) {
        Fail 'REFUSING TO PUBLISH: A PREVIOUS PUBLISH DID NOT FINISH' @(
            "$Share is in place and untouched, but $staging is left over from an"
            'earlier publish that was interrupted. It is not live, but this script'
            'does not delete a build it did not just create.'
            "Look at it; if it is not needed, delete $staging and run this again.")
    }
    if ($leftOld) { Info "left over from earlier publishes, removed once this one succeeds: $($leftOld -join ', ')" }

    # The swap below replaces the folder, and a folder created fresh carries only
    # what it inherits from the parent: every explicit ACE on the old one is lost,
    # including the one the server's updater reads through. That is how the
    # 12 November publish silently disabled the auto-deploy (MBA-1032). So carry
    # the old folder's explicit ACEs over, and make sure the reader's is among
    # them - set on the empty staging folder, before anything is copied in, so
    # every file inherits it and the rename keeps it.
    #
    # Everything from here up to the swap only builds the staging folder; the
    # live share is not touched. If any of it fails, the staging folder is this
    # run's own unfinished work - remove it, so it is not mistaken next time for
    # the leftover of a failed swap. A finally, not a catch: Ctrl+C stops the
    # pipeline without running catch, and would leave a half-copied folder.
    $built = $false
    try {
        $carried = @()
        $protected = $false
        if (Test-Path $Share) {
            $oldAcl    = (Get-Item $Share).GetAccessControl('Access')
            $carried   = @($oldAcl.GetAccessRules($true, $false, $sidType))
            # Inheritance disabled on purpose (to shed a broad parent grant) must stay
            # disabled, or the fresh folder quietly brings that grant back.
            $protected = $oldAcl.AreAccessRulesProtected
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

        # Applied after the copy, not before: with inheritance cut, the publisher's
        # own write access may come only from the parent.
        if ($protected) {
            $acl = (Get-Item $staging).GetAccessControl('Access')
            $acl.SetAccessRuleProtection($true, $false)
            (Get-Item $staging).SetAccessControl($acl)
            Info 'permissions: inheritance stays disabled, as on the previous folder'
        }

        # Check it on staging, while the previous build is still in place, so a
        # failure leaves the server something it can read; again after the swap.
        Assert-Readable $staging 'NOT PUBLISHED (previous build left in place)'
        $built = $true
    } finally {
        if (-not $built -and (Test-Path -LiteralPath $staging)) { [void](Remove-Leftover $staging) }
    }

    # ------------------------------------------------------------------ swap
    # It used to be Remove-Item $Share then Move-Item $staging $Share. On
    # 15 November the delete succeeded, the move hit the SMB race above, and the
    # script exited with no share at all (MBA-1033). Now nothing is deleted
    # until the new build is in place and verified.
    # Every failure branch below decides from what is on disk, not from which
    # call threw: over SMB a rename can take effect and still report an error.
    # Manual advice is always rename-then-rename, never delete-then-move.
    $staleNote = 'Run this again.'
    $old = $null
    if (Test-Path -LiteralPath $Share) {
        $old = "$Share.old-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        try { Move-WithRetry $Share $old }
        catch {
            $err = $_.Exception.Message
            if (Test-Path -LiteralPath $Share) {
                if (-not (Remove-Leftover $staging)) { $staleNote = "Delete $staging by hand first, then run this again." }
                Fail 'NOT PUBLISHED: COULD NOT MOVE THE LIVE BUILD ASIDE' @(
                    "$Share is untouched and still live: $err"
                    'Something on the share is probably holding a handle on it.'
                    $staleNote)
            }
            if (-not (Test-Path -LiteralPath $old)) {
                Fail "THE SHARE IS MISSING: $Share" @(
                    "Moving it aside failed ($err), and it is not at $old either."
                    "The new build is intact at $staging; nothing was deleted."
                    "Run this again - it moves the new build into place first - or by hand:"
                    "  Rename-Item '$staging' '$leaf'")
            }
            Info "moving the live build aside reported '$err', but it is at $old - carrying on"
        }
    }

    $moveError = $null
    try { Move-WithRetry $staging $Share } catch { $moveError = $_.Exception.Message }
    if ($moveError -and (Test-Path -LiteralPath $Share) -and -not (Test-Path -LiteralPath $staging) -and
        -not (Get-BuildProblem $Share)) {
        Info "moving the new build in reported '$moveError', but it is in place - carrying on"
        $moveError = $null
    }
    if ($moveError) {
        if (Test-Path -LiteralPath $Share) {
            # Something is at $Share, and it is not the new build. Do not guess.
            Fail 'NOT PUBLISHED: SOMETHING UNEXPECTED IS AT THE SHARE' @(
                "Moving the new build in failed ($moveError), and $Share exists but is not it."
                'Nothing was deleted. Look by hand at:'
                "  $Share"
                "  new build:      $staging"
                $(if ($old) { "  previous build: $old" } else { '  (there was no previous build)' }))
        }
        if (-not $old) {
            Fail 'NOT PUBLISHED: COULD NOT MOVE THE NEW BUILD INTO PLACE' @(
                "error: $moveError"
                "The new build is complete in $staging. Run this again: it moves"
                "that folder into place first, or do it by hand:  Rename-Item '$staging' '$leaf'")
        }
        $putBack = $null
        try { Move-WithRetry $old $Share } catch { $putBack = $_.Exception.Message }
        if ((Test-Path -LiteralPath $Share) -and -not (Test-Path -LiteralPath $old)) {
            if (-not (Remove-Leftover $staging)) { $staleNote = "Delete $staging by hand first, then run this again." }
            Fail 'NOT PUBLISHED: COULD NOT MOVE THE NEW BUILD INTO PLACE' @(
                "error: $moveError"
                "The previous build was put back at $Share and is still live."
                $staleNote)
        }
        Fail "THE SHARE IS MISSING: $Share" @(
            "Moving the new build in failed:     $moveError"
            "and putting the previous back too:  $putBack"
            'Both builds are intact, nothing was deleted:'
            "  new build:      $staging"
            "  previous build: $old"
            'Run this again - it moves the new build into place before anything else -'
            "or do it by hand:  Rename-Item '$staging' '$leaf'")
    }

    # ---------------------------------------------------------------- verify
    # The share must exist and hold this build, readable by us and - by its
    # ACL - by the server. If not, the previous build is kept beside it.
    $keepOld = if ($old) {
        "The previous build is kept at $old. To put it back, rename, never delete first:  " +
        "Rename-Item '$Share' '$leaf.bad'; Rename-Item '$old' '$leaf'; then delete '$Share.bad'"
    } else { 'There is no previous build to fall back to.' }
    $problem = Get-BuildProblem $Share
    if (-not $problem) {
        $published = (Get-Content -LiteralPath (Join-Path $Share 'build.md5') -Raw).Trim()
        if ($published -ne $hash) { $problem = "it holds build $published, not this one ($hash)" }
    }
    if ($problem) {
        Fail 'PUBLISH FAILED VERIFICATION: THE SHARE DOES NOT HOLD A READABLE BUILD' @(
            "$Share - $problem", $keepOld)
    }
    try { Assert-Readable $Share 'PUBLISHED, BUT' }
    catch { Write-Host "  $keepOld"; throw }
    Info "verified: $Share holds build $hash, complete and readable"
    Info "ACL check: $ReaderAccount has a read grant on the folder and payload\dist\index.cjs"
    Info '(NTFS only - the updater run below is the end-to-end proof)'

    # Only now is the previous build expendable.
    foreach ($o in @($old) + $leftOld) {
        if ($o -and (Remove-Leftover $o)) { Info "removed $o" }
    }

    Write-Host ''
    Write-Host 'PUBLISHED' -ForegroundColor Green
    Write-Host "  $Share"
    Write-Host "  build md5: $hash"
    Write-Host ''
    Write-Host 'The server picks this up on its next check (daily, and at startup).'
    Write-Host 'To apply it right now, on the server as administrator:'
    Write-Host '  Start-ScheduledTask -TaskName QCCAnalyticsUpdate'
    Write-Host '  Get-ScheduledTaskInfo -TaskName QCCAnalyticsUpdate | Select-Object LastTaskResult   # 5 = access denied'
    Write-Host '  Get-Content C:\apps\qcc-updater\update.log -Tail 20'
}
