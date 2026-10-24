<#
.SYNOPSIS
  Hide Windows UI clutter (taskbar items, ads, suggestions) with backup and restore.
.EXAMPLE
  .\winopt.ps1 list
  .\winopt.ps1 status
  .\winopt.ps1 apply basic -WhatIf
  .\winopt.ps1 apply full -Only taskbar-news,fx-aero-peek
  .\winopt.ps1 restore
  .\winopt.ps1 apply full -Yes   # no prompt, still reboots
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'status', 'apply', 'restore')]
    [string]$Command = 'status',

    [Parameter(Position = 1)]
    [string]$Preset = 'basic',

    [string[]]$Only,
    [string]$From,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$BackupDir = Join-Path $PSScriptRoot 'backups'

# --- helpers ---------------------------------------------------------------

function Get-OsTag {
    if ([Environment]::OSVersion.Version.Build -ge 22000) { '11' } else { '10' }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
}

function Get-Tweaks {
    $all = (Get-Content (Join-Path $PSScriptRoot 'tweaks.json') -Raw -Encoding UTF8 | ConvertFrom-Json).tweaks
    @($all | Where-Object { $_.os -contains $script:Os })
}

function Select-Tweaks($tweaks) {
    $file = Join-Path $PSScriptRoot "presets\$Preset.json"
    if (-not (Test-Path $file)) { throw "Preset not found: $Preset" }
    $p = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $picked = @($tweaks | Where-Object { $p.groups -contains $_.group -and $p.exclude -notcontains $_.id })
    if ($Only) {
        $unknown = @($Only | Where-Object { $picked.id -notcontains $_ })
        if ($unknown) { throw "Not in preset '$Preset': $($unknown -join ', ')" }
        $picked = @($picked | Where-Object { $Only -contains $_.id })
    }
    $picked
}

# --- commands --------------------------------------------------------------

function Invoke-List($tweaks) {
    $tweaks | ForEach-Object {
        [pscustomobject]@{ Id = $_.id; Group = $_.group; Admin = (Test-NeedsAdmin $_); Name = $_.name }
    } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

function Invoke-Status($tweaks) {
    Write-Host "Windows $Os | admin: $IsAdmin"
    $tweaks | ForEach-Object {
        [pscustomobject]@{ Id = $_.id; Group = $_.group; State = (Get-TweakState $_); Name = $_.name }
    } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

function Invoke-Apply($tweaks) {
    $todo = @(); $skipped = @()
    foreach ($t in (Select-Tweaks $tweaks)) {
        if ((Get-TweakState $t) -eq 'applied') { continue }
        if ((Test-NeedsAdmin $t) -and -not $IsAdmin) { $skipped += $t.id; continue }
        $todo += $t
    }
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
    [ordered]@{ preset = $Preset; os = $Os; date = (Get-Date).ToString('s'); values = $records } |
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
    if ($failed.Count -eq $todo.Count) { Write-Host 'No tweak was applied. Skipping restart.' -ForegroundColor Red; exit 1 }
    Restart-Pc
    if ($failed) { exit 1 }
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
    Write-Host "Restoring from: $file"

    # Only values that differ from the backup need work.
    $records = @($backup.values | Where-Object {
        $cur = Read-Value $_.path $_.name
        -not ($cur.exists -eq $_.exists -and (-not $_.exists -or (Test-ValueMatch $cur $_)))
    })
    if (-not $records) {
        Write-Host 'Your system already matches this backup. Nothing to restore.' -ForegroundColor Green
        if (-not $WhatIfPreference) { Rename-Item $file ((Split-Path $file -Leaf) + '.restored') }
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
    # Mark as used so the next restore steps back further.
    if (-not $failed) { Rename-Item $file ((Split-Path $file -Leaf) + '.restored') }
    if ($done) { Restart-Pc } else { Write-Host 'Nothing was restored. Skipping restart.' -ForegroundColor Red }
    if ($failed) { exit 1 }
}

# --- main ------------------------------------------------------------------

try {
    $Os = Get-OsTag
    $IsAdmin = Test-Admin
    if ($Os -ne '10') { throw "Windows $Os is not supported yet." }

    $tweaks = Get-Tweaks
    switch ($Command) {
        'list'    { Invoke-List $tweaks }
        'status'  { Invoke-Status $tweaks }
        'apply'   { Invoke-Apply $tweaks }
        'restore' { Invoke-Restore }
    }
} catch {
    # One readable line instead of a PowerShell stack trace.
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
