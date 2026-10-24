<#
.SYNOPSIS
  Hide Windows UI clutter (taskbar items, ads, suggestions) with backup and restore.
.EXAMPLE
  .\winopt.ps1 list
  .\winopt.ps1 status
  .\winopt.ps1 apply basic -WhatIf
  .\winopt.ps1 apply full -Only taskbar-news,fx-aero-peek
  .\winopt.ps1 restore
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
    [switch]$NoRestart
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

function Restart-Explorer {
    if ($NoRestart) { return }
    Write-Host 'Restarting Explorer...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
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
    if (-not $todo) { Write-Host 'Nothing to change.'; return }

    if ($WhatIfPreference) {
        $rows = foreach ($t in $todo) {
            foreach ($v in $t.values) {
                $cur = Read-Value $v.path $v.name
                if (Test-ValueMatch $cur $v) { continue }
                $old = if ($cur.exists) { @($cur.value) -join ',' } else { '(unset)' }
                [pscustomobject]@{ Id = $t.id; Value = $v.name; Current = $old; New = $v.value }
            }
        }
        $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
        return
    }

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
    Restart-Explorer
    if ($todo.group -contains 'effects') { Write-Host 'Sign out and back in to fully apply visual effects.' }
    if ($failed) { exit 1 }
}

function Invoke-Restore {
    $file = if ($From) { $From } else {
        Get-ChildItem $BackupDir -Filter '*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty FullName
    }
    if (-not $file -or -not (Test-Path $file)) { throw 'No backup found.' }
    $backup = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Restoring from: $file"

    $records = @($backup.values); [array]::Reverse($records)
    $done = 0; $failed = 0
    foreach ($r in $records) {
        $cur = Read-Value $r.path $r.name
        if ($cur.exists -eq $r.exists -and (-not $r.exists -or (Test-ValueMatch $cur $r))) { continue }
        $state = if ($r.exists) { @($r.value) -join ',' } else { '(unset)' }
        if ($WhatIfPreference) { Write-Host "  $($r.path)\$($r.name) -> $state"; continue }
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
    if ($WhatIfPreference) { return }

    Write-Host "Restored $done values." -ForegroundColor Green
    Restart-Explorer
    if ($failed) { exit 1 }
    # Mark as used so the next restore steps back further.
    Rename-Item $file ((Split-Path $file -Leaf) + '.restored')
}

# --- main ------------------------------------------------------------------

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
