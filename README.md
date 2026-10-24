# winopt

PowerShell CLI that declutters Windows 10: hides News and Interests, extra taskbar buttons, ads, suggestions and Bing results. Every change is backed up and can be restored.

## Usage
Run from this folder. No need to change the machine's ExecutionPolicy:

```
powershell -ExecutionPolicy Bypass -File .\winopt.ps1 <command>
```

| Command | Description |
|---|---|
| `list` | List all tweaks |
| `status` | Show each tweak's state: `applied`, `partial` or `default` |
| `apply basic -WhatIf` | Preview changes without writing anything |
| `apply basic` | Back up, then apply the `basic` preset |
| `apply full` | Same as `basic`, plus disables visual effects (transparency, Aero Peek, animations) |
| `apply full -Only taskbar-news,fx-aero-peek` | Apply only the listed tweaks |
| `restore` | Undo the last `apply`; run again to step back further |
| `restore -From backups\<file>.json` | Restore from a specific backup |

Add `-NoRestart` to skip restarting Explorer.

## Notes
- Most tweaks apply to the **current user** only. Run once per user.
- `taskbar-news`, `taskbar-meetnow` and `search-web-policy` need admin (see the `Admin` column in `list`). Run PowerShell as Administrator from the same user account.
- The `effects` group needs a sign-out to fully apply.
- Backups in `backups/` contain machine and user names and are git-ignored.

## Adding a tweak
Add an entry to `tweaks.json` (`id`, `group`, `os`, `name`, `values`). If its group is in a preset, the preset picks it up. Test with `-WhatIf` first.
