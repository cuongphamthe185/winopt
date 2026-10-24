<#
.SYNOPSIS
  Hide Windows UI clutter (taskbar items, ads, suggestions) with backup and restore.
.EXAMPLE
  .\winopt.ps1                   # interactive menu
  .\winopt.ps1 menu -Elevate     # menu as admin (used by winopt.bat)
  .\winopt.ps1 list
  .\winopt.ps1 status
  .\winopt.ps1 backups
  .\winopt.ps1 apply basic -WhatIf
  .\winopt.ps1 apply full -Only taskbar-search-icon,fx-aero-peek
  .\winopt.ps1 restore
  .\winopt.ps1 apply full -Yes   # no prompt, still reboots
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('menu', 'list', 'status', 'backups', 'apply', 'restore')]
    [string]$Command = 'menu',

    [Parameter(Position = 1)]
    [string]$Preset = 'basic',

    [string[]]$Only,
    [string]$From,
    [switch]$Yes,
    [switch]$Elevate
)

$ErrorActionPreference = 'Stop'
$BackupDir = Join-Path $PSScriptRoot 'backups'
$ExitCode = 0
$Rebooting = $false

# --- helpers ---------------------------------------------------------------

$Editions = [ordered]@{ home = 'Home'; pro = 'Pro'; enterprise = 'Enterprise'; education = 'Education' }

# '10' or '11'; empty for anything older (PowerShell 5.1 also runs on Windows 7 and 8.1).
function Get-OsTag {
    $v = [Environment]::OSVersion.Version
    if ($v.Major -ne 10) { return '' }
    if ($v.Build -ge 22000) { '11' } else { '10' }
}

# Edition family from EditionID; empty for Server, IoT and anything unknown.
function Get-EditionTag($editionId) {
    switch -Regex ($editionId) {
        '^Core' { 'home'; break }
        '^Professional' { 'pro'; break }
        '^Enterprise' { 'enterprise'; break }
        '^Education' { 'education'; break }
        default { '' }
    }
}

# No editions list means the tweak works on every edition.
function Test-EditionSupported($tweak) {
    -not $tweak.editions -or (@($tweak.editions) -contains $script:Edition)
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# User signed in at the console; empty when unknown (e.g. remote session).
function Get-ConsoleUser {
    try { [string](Get-CimInstance Win32_ComputerSystem).UserName } catch { '' }
}

function Test-NeedsAdmin($tweak) {
    foreach ($v in $tweak.values) {
        if ($v.path -like 'HKLM:*' -or $v.path -like '*\Policies\*') { return $true }
    }
    $false
}

# Current state of one registry value.
function Read-Value($path, $name) {
    $key = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    $state = [ordered]@{ path = $path; name = $name; keyExisted = [bool]$key; exists = $false; type = $null; value = $null }
    if ($key -and ($key.GetValueNames() -contains $name)) {
        $state.exists = $true
        $state.type = $key.GetValueKind($name).ToString()
        $state.value = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
    }
    $state
}

function Test-ValueMatch($cur, $v) {
    $cur.exists -and ((@($cur.value) -join ',') -eq (@($v.value) -join ','))
}

function Write-Value($path, $name, $type, $value) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
    if ($type -eq 'Binary') { $value = [byte[]]$value }
    New-ItemProperty -LiteralPath $path -Name $name -PropertyType $type -Value $value -Force | Out-Null
}

function Get-TweakState($tweak) {
    $hits = @($tweak.values | Where-Object { Test-ValueMatch (Read-Value $_.path $_.name) $_ }).Count
    if ($hits -eq $tweak.values.Count) { 'applied' } elseif ($hits -gt 0) { 'partial' } else { 'default' }
}

$RebootDelay = 10

# Real runs always reboot; -WhatIf only previews. Returns $true to continue.
function Confirm-Run {
    if ($WhatIfPreference) {
        Write-Host 'Note: a real run will restart your computer.' -ForegroundColor Yellow
        return $false
    }
    Write-Host "WARNING: This will change system settings and restart your computer in $RebootDelay seconds." -ForegroundColor Red
    Write-Host 'Save your work and close all apps before continuing.' -ForegroundColor Red
    if ($Yes) { Write-Host 'Confirmed by -Yes.'; return $true }
    $answer = try { Read-Host 'Continue? [y/N]' } catch { '' }
    if ($answer -match '^(y|yes)$') { return $true }
    Write-Host 'Cancelled. No changes were made.'
    $false
}

function Restart-Pc {
    Write-Host "Restarting in $RebootDelay seconds. To cancel, run: shutdown /a" -ForegroundColor Yellow
    shutdown.exe /r /t $RebootDelay /c 'winopt: restarting to apply changes'
    $script:Rebooting = $true
}

# Catch typos in tweaks.json early instead of silently never applying a tweak.
function Assert-Tweaks($all) {
    $ids = @{}; $seen = @{}
    foreach ($t in $all) {
        if ($ids[$t.id]) { throw "tweaks.json: duplicate id '$($t.id)'" }
        $ids[$t.id] = $true
        if (-not $t.os -or @($t.os | Where-Object { $_ -notin '10', '11' })) { throw "tweaks.json: invalid os in '$($t.id)'" }
        if ($null -ne $t.editions -and (-not @($t.editions).Count -or @($t.editions | Where-Object { -not $Editions.Contains([string]$_) }))) {
            throw "tweaks.json: invalid editions in '$($t.id)'"
        }
        foreach ($os in $t.os) {
            foreach ($v in $t.values) {
                $key = "$os|$($v.path)|$($v.name)"
                if ($seen[$key]) { throw "tweaks.json: '$($seen[$key])' and '$($t.id)' both write $($v.path)\$($v.name)" }
                $seen[$key] = $t.id
            }
        }
    }
}

# All tweaks go to $AllTweaks; returns only those for this Windows version.
function Get-Tweaks {
    $all = @((Get-Content (Join-Path $PSScriptRoot 'tweaks.json') -Raw -Encoding UTF8 | ConvertFrom-Json).tweaks)
    Assert-Tweaks $all
    $script:AllTweaks = $all
    @($all | Where-Object { $_.os -contains $script:Os })
}

function Select-Tweaks($tweaks) {
    $file = Join-Path $PSScriptRoot "presets\$Preset.json"
    if (-not (Test-Path $file)) { throw "Preset not found: $Preset" }
    $p = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $picked = @($tweaks | Where-Object { $p.groups -contains $_.group -and $p.exclude -notcontains $_.id })
    if ($Only) {
        $unknown = @($Only | Where-Object { $picked.id -notcontains $_ })
        $otherOs = @($unknown | Where-Object { $tweaks.id -notcontains $_ -and $script:AllTweaks.id -contains $_ })
        if ($otherOs) { throw "Not available on Windows ${Os}: $($otherOs -join ', ')" }
        if ($unknown) { throw "Not in preset '$Preset': $($unknown -join ', ')" }
        $picked = @($picked | Where-Object { $Only -contains $_.id })
    }
    $picked
}

# --- commands --------------------------------------------------------------

function Invoke-List($tweaks) {
    $tweaks | ForEach-Object {
        $eds = if ($_.editions) { @($_.editions) -join ',' } else { 'all' }
        [pscustomobject]@{ Id = $_.id; Group = $_.group; Admin = (Test-NeedsAdmin $_); Editions = $eds; Name = $_.name }
    } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

function Invoke-Status($tweaks) {
    Write-Host "$OsLabel | admin: $IsAdmin"
    $tweaks | ForEach-Object {
        $state = if (Test-EditionSupported $_) { Get-TweakState $_ } else { 'n/a' }
        [pscustomobject]@{ Id = $_.id; Group = $_.group; State = $state; Name = $_.name }
    } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

function Invoke-Apply($tweaks) {
    $todo = @(); $noEdition = @(); $skipped = @()
    foreach ($t in (Select-Tweaks $tweaks)) {
        # Edition first, so an unsupported tweak is never reported as "needs admin".
        if (-not (Test-EditionSupported $t)) { $noEdition += $t.id; continue }
        if ((Get-TweakState $t) -eq 'applied') { continue }
        if ((Test-NeedsAdmin $t) -and -not $IsAdmin) { $skipped += $t.id; continue }
        $todo += $t
    }
    if ($noEdition) { Write-Warning "Not supported on ${OsLabel}, skipped: $($noEdition -join ', ')" }
    if ($skipped) { Write-Warning "Needs admin, skipped: $($skipped -join ', ')" }
    if (-not $todo) {
        if ($skipped) {
            Write-Host "All other tweaks in preset '$Preset' are already applied. Run as Administrator to apply the rest." -ForegroundColor Yellow
        } else {
            Write-Host "Your system is already optimized for preset '$Preset'. No changes needed." -ForegroundColor Green
        }
        return
    }

    $rows = foreach ($t in $todo) {
        foreach ($v in $t.values) {
            $cur = Read-Value $v.path $v.name
            if (Test-ValueMatch $cur $v) { continue }
            $old = if ($cur.exists) { @($cur.value) -join ',' } else { '(unset)' }
            [pscustomobject]@{ Id = $t.id; Value = $v.name; Current = $old; New = $v.value }
        }
    }
    $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    if (-not (Confirm-Run)) { return }

    # Backup every value we touch, then write.
    $records = @($todo | ForEach-Object { $_.values } | ForEach-Object { Read-Value $_.path $_.name })
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $file = Join-Path $BackupDir ("{0}_{1}_{2}.json" -f $env:COMPUTERNAME, $env:USERNAME, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    [ordered]@{ preset = $Preset; os = $Os; edition = $Edition; date = (Get-Date).ToString('s'); values = $records } |
        ConvertTo-Json -Depth 5 | Set-Content $file -Encoding UTF8
    Write-Host "Backup: $file"

    $failed = @()
    foreach ($t in $todo) {
        try {
            foreach ($v in $t.values) { Write-Value $v.path $v.name $v.type $v.value }
            Write-Host "  applied  $($t.id)" -ForegroundColor Green
        } catch {
            $failed += $t.id
            Write-Host "  failed   $($t.id): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    if ($failed) { $script:ExitCode = 1 }
    if ($failed.Count -eq $todo.Count) { Write-Host 'No tweak was applied. Skipping restart.' -ForegroundColor Red; return }
    Restart-Pc
}

# Mark a backup as used so the next restore steps back further.
function Set-Restored($file) {
    if ($file -notlike '*.restored') { Rename-Item $file ((Split-Path $file -Leaf) + '.restored') }
}

function Invoke-Restore {
    $file = if ($From) { $From } else {
        Get-ChildItem $BackupDir -Filter '*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty FullName
    }
    if ($From -and -not (Test-Path $From)) { throw "Backup file not found: $From" }
    if (-not $file) {
        Write-Host 'No backup to restore. Nothing was changed.' -ForegroundColor Yellow
        return
    }
    $backup = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    # Checked before anything else, so a backup from another version is never marked as used.
    if ($backup.os -ne $Os) {
        $made = if ($backup.os) { "Windows $($backup.os)" } else { 'an unknown Windows version' }
        throw "This backup was made on $made and cannot be restored on Windows $Os."
    }
    Write-Host "Restoring from: $file"

    # Only restore values winopt itself manages, so a tampered backup cannot write anything else.
    # Not filtered by edition: anything winopt wrote must stay undoable.
    $known = @{}
    $script:AllTweaks.values | ForEach-Object { $known["$($_.path)|$($_.name)"] = $true }
    $types = 'DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary'
    $valid = @($backup.values | Where-Object { $known["$($_.path)|$($_.name)"] -and (-not $_.exists -or $types -contains $_.type) })
    $rejected = @($backup.values).Count - $valid.Count
    if ($rejected) { Write-Host "Ignored $rejected unknown values in this backup." -ForegroundColor Red }

    # Only values that differ from the backup need work.
    $records = @($valid | Where-Object {
        $cur = Read-Value $_.path $_.name
        -not ($cur.exists -eq $_.exists -and (-not $_.exists -or (Test-ValueMatch $cur $_)))
    })
    if (-not $records) {
        Write-Host 'Your system already matches this backup. Nothing to restore.' -ForegroundColor Green
        if (-not $WhatIfPreference) { Set-Restored $file }
        return
    }
    [array]::Reverse($records)
    $records | ForEach-Object {
        [pscustomobject]@{ Value = "$($_.path)\$($_.name)"; Restore = $(if ($_.exists) { @($_.value) -join ',' } else { '(unset)' }) }
    } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    if (-not (Confirm-Run)) { return }

    $done = 0; $failed = 0
    foreach ($r in $records) {
        try {
            if ($r.exists) {
                Write-Value $r.path $r.name $r.type $r.value
            } else {
                Remove-ItemProperty -LiteralPath $r.path -Name $r.name
                # Drop keys we created if they are now empty.
                $key = Get-Item -LiteralPath $r.path
                if (-not $r.keyExisted -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) {
                    Remove-Item -LiteralPath $r.path
                }
            }
            $done++
        } catch {
            $failed++
            Write-Host "  failed   $($r.path)\$($r.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "Restored $done values." -ForegroundColor Green
    if (-not $failed) { Set-Restored $file }
    if ($failed) { $script:ExitCode = 1 }
    if ($done) { Restart-Pc } else { Write-Host 'Nothing was restored. Skipping restart.' -ForegroundColor Red }
}

# All backups, newest first.
function Get-Backups {
    $i = 0
    Get-ChildItem $BackupDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*.json' -or $_.Name -like '*.json.restored' } |
        Sort-Object LastWriteTime -Descending | ForEach-Object {
            $b = try { Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
            [pscustomobject]@{
                '#'    = ++$i
                Date   = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
                OS     = $(if ($b -and $b.os) { $b.os } else { '?' })
                Preset = $(if ($b) { $b.preset } else { '?' })
                Values = $(if ($b) { @($b.values).Count } else { 0 })
                Used   = $(if ($_.Name -like '*.restored') { 'yes' } else { 'no' })
                Path   = $_.FullName
            }
        }
}

function Invoke-Backups {
    $list = @(Get-Backups)
    if (-not $list) { Write-Host 'No backups yet.' -ForegroundColor Yellow; return $list }
    $list | Select-Object '#', Date, OS, Preset, Values, Used | Format-Table -AutoSize | Out-String | Write-Host
    $list
}

# --- menu ------------------------------------------------------------------

# Relaunch as admin via UAC. Returns $true when the elevated copy took over.
function Request-Admin {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", 'menu')
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -WorkingDirectory $PSScriptRoot
        return $true
    } catch {
        $n = @($script:Tweaks | Where-Object { (Test-NeedsAdmin $_) -and (Test-EditionSupported $_) }).Count
        Write-Host "Admin was not granted. $n tweaks need admin and will be skipped." -ForegroundColor Yellow
        $answer = Read-Host 'Continue without admin? [y/N]'
        if ($answer -match '^(y|yes)$') { return $false }
        exit 0
    }
}

function Wait-Enter { [void](Read-Host 'Press Enter to continue') }

function Invoke-Menu {
    if ($Elevate -and -not $IsAdmin -and (Request-Admin)) { return }

    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $console = Get-ConsoleUser
    $otherUser = $console -and ($console -ne $me)

    $items = [ordered]@{
        '1' = 'Status'
        '2' = 'Preview basic'
        '3' = 'Apply basic'
        '4' = 'Preview full'
        '5' = 'Apply full'
        '6' = 'Restore last change'
        '7' = 'Restore from a backup...'
        '8' = 'List tweaks'
        '0' = 'Exit'
    }
    while ($true) {
        Write-Host ''
        Write-Host "winopt - $OsLabel cleanup    [admin: $(if ($IsAdmin) { 'yes' } else { 'no' })]" -ForegroundColor Cyan
        if ($otherUser) {
            Write-Host "WARNING: running as $me, but $console is signed in. Changes will apply to $me." -ForegroundColor Red
        }
        $items.GetEnumerator() | ForEach-Object { Write-Host " $($_.Key). $($_.Value)" }
        $choice = Read-Host 'Choose'
        if ($null -eq $choice -or $choice -eq '0') { return }
        if (-not $items.Contains($choice)) { continue }

        try {
            $script:From = $null; $script:Only = $null
            switch ($choice) {
                '1' { Invoke-Status $script:Tweaks }
                '2' { $script:Preset = 'basic'; $WhatIfPreference = $true; Invoke-Apply $script:Tweaks; $WhatIfPreference = $false }
                '3' { $script:Preset = 'basic'; Invoke-Apply $script:Tweaks }
                '4' { $script:Preset = 'full'; $WhatIfPreference = $true; Invoke-Apply $script:Tweaks; $WhatIfPreference = $false }
                '5' { $script:Preset = 'full'; Invoke-Apply $script:Tweaks }
                '6' { Invoke-Restore }
                '7' {
                    $list = @(Invoke-Backups)
                    if ($list) {
                        $pick = Read-Host 'Choose backup (0 = back)'
                        $hit = $list | Where-Object { [string]$_.'#' -eq $pick }
                        if ($hit) { $script:From = $hit.Path; Invoke-Restore }
                    }
                }
                '8' { Invoke-List $script:Tweaks }
            }
        } catch {
            $WhatIfPreference = $false
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        if ($script:Rebooting) { Wait-Enter; return }
        Wait-Enter
    }
}

# --- main ------------------------------------------------------------------

try {
    # Version and edition are checked before any command, including read-only ones.
    $Os = Get-OsTag
    if (-not $Os) { throw "Windows $([Environment]::OSVersion.Version) is not supported. Only Windows 10 and 11 are." }
    $EditionId = [string](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID
    $Edition = Get-EditionTag $EditionId
    if (-not $Edition) { throw "Windows edition '$EditionId' is not supported. Only Home, Pro, Enterprise and Education are." }
    $OsLabel = "Windows $Os $($Editions[$Edition])"
    $IsAdmin = Test-Admin

    $Tweaks = Get-Tweaks
    switch ($Command) {
        'menu'    { Invoke-Menu }
        'list'    { Invoke-List $Tweaks }
        'status'  { Invoke-Status $Tweaks }
        'backups' { [void](Invoke-Backups) }
        'apply'   { Invoke-Apply $Tweaks }
        'restore' { Invoke-Restore }
    }
} catch {
    # One readable line instead of a PowerShell stack trace.
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
exit $ExitCode
