# winopt

PowerShell CLI that declutters Windows 10: hides News and Interests, extra taskbar buttons, ads, suggestions and Bing results. Every change is backed up and can be restored.

See [TWEAKS.md](TWEAKS.md) for every tweak, why it was chosen, and which tweaks are left out on purpose.

## Quick start
1. Download the ZIP from GitHub. Right-click it > Properties > tick **Unblock** > OK, then extract. This avoids Windows SmartScreen warnings.
2. Double-click `winopt.bat` and click **Yes** on the admin prompt.
3. Pick an option from the menu:

```
 1. Status
 2. Preview basic
 3. Apply basic
 4. Preview full
 5. Apply full
 6. Restore last change
 7. Restore from a backup...
 8. List tweaks
 0. Exit
```

Apply and restore still show the red warning, ask `[y/N]` and restart the computer.
If you click **No** on the admin prompt, the menu offers to continue without admin (admin-only tweaks are skipped).
If the admin prompt uses a different account than the one signed in, the menu shows a red warning: changes go to that other account.

## Usage
Command line, from this folder. No need to change the machine's ExecutionPolicy:

```
powershell -ExecutionPolicy Bypass -File .\winopt.ps1 <command>
```

| Command | Description |
|---|---|
| (no command) | Interactive menu (add `-Elevate` to ask for admin, as `winopt.bat` does) |
| `list` | List all tweaks |
| `backups` | List all backups, newest first (`Used = yes` means already restored once) |
| `status` | Show each tweak's state: `applied`, `partial` or `default` |
| `apply basic -WhatIf` | Preview changes without writing anything |
| `apply basic` | Back up, apply the `basic` preset, then restart |
| `apply full` | Same as `basic`, plus disables visual effects (transparency, Aero Peek, animations, shadows) |
| `apply full -Only taskbar-news,fx-aero-peek` | Apply only the listed tweaks |
| `restore` | Undo the last `apply`, then restart; run again to step back further |
| `restore -From backups\<file>.json` | Restore from a specific backup |

## Confirmation and restart
- `apply` and `restore` first list what will change, then show a red warning and ask `Continue? [y/N]`. Only `y` continues; anything else stops with no changes.
- After changes are made, **the computer restarts in 10 seconds**. Save your work first. To cancel the restart, run `shutdown /a`.
- The restart is required. Applying without it can leave Windows unstable until the next reboot.
- If nothing needs to change, the script says so and exits without asking or restarting.
- `-WhatIf` never asks, changes or restarts anything.
- `-Yes` skips the `[y/N]` prompt (e.g. `apply full -Yes`). The red warning is still shown and **the computer still restarts in 10 seconds without asking**. Use it only for unattended runs across many machines; regular users should not add it.
- There is no option to skip the restart.

## Notes
- Most tweaks apply to the **current user** only. Run once per user.
- `taskbar-news`, `taskbar-meetnow`, `search-web-policy` and `perf-delivery-opt` need admin (see the `Admin` column in `list`).
- The `performance` group only uses safe, reversible settings. Risky tweaks (disabling Defender, VBS, page file, services, System Restore, DNS cache, GPU scheduling) are intentionally not included. Run PowerShell as Administrator from the same user account.
- Backups in `backups/` contain machine and user names and are git-ignored.

## Adding a tweak
Add an entry to `tweaks.json` (`id`, `group`, `os`, `name`, `values`). If its group is in a preset, the preset picks it up. Test with `-WhatIf` first.
