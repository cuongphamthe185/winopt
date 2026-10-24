# winopt

PowerShell CLI that hides Windows UI clutter (taskbar items, ads, suggestions) via registry, with backup and restore. Windows 10 only for now; Windows 11 is planned. No GUI.

## Layout
- `winopt.ps1`: entry point (`list`, `status`, `apply <preset>`, `restore`, plus `-WhatIf`, `-Only`, `-From`, `-Yes`)
- `tweaks.json`: all tweaks (id, group, os, name, registry values)
- `presets/*.json`: which groups/ids a preset applies
- `backups/`: per-run JSON backups, git-ignored

## Rules
- Project language: everything in the repo is English (code, identifiers, comments, JSON data, output messages, README and other docs, commit messages). Keep it short and readable.
- Commit messages: English, one short line. No Co-Authored-By or other Claude attribution in commits or PRs.
- Communication with the user: always reply in Vietnamese, short but complete.
- Ask before changing the system: any run that writes to the machine (`apply` or `restore` without `-WhatIf`, direct registry edits) needs the user's review and OK first. Read-only runs (`list`, `status`, `-WhatIf`) are fine.
- Security check after every task: before finishing or committing, review the diff and outputs for keys, tokens, passwords, credentials or personal data (user names, machine names, emails, paths with user names). Never commit `backups/`. Report the result of this check to the user.

## Run behavior
- A real `apply`/`restore` with pending changes shows the changes, a red warning and a `[y/N]` prompt; only `y`/`yes` continues.
- After a real run that changed something, the PC reboots after 10 seconds (`shutdown /r /t 10`, cancel with `shutdown /a`). Reboot is mandatory: restarting only Explorer left Windows unstable.
- Never restart Explorer. Do not add `-NoReboot`.
- `-Yes` skips only the prompt (for unattended runs); the warning and reboot still happen. Keep docs warning that it reboots without asking.
- Nothing pending: print a clear message and exit without prompt or reboot. `-WhatIf` never prompts or reboots, and notes that a real run reboots.

## Tweak conventions
- Every tweak must be reversible by `restore`; never delete a key or value that existed before.
- Prefer HKCU. Paths under HKLM or any `\Policies\` key are treated as admin-only and skipped without elevation.
- Some HKCU keys are ACL-protected on recent Windows 10 builds (e.g. `CurrentVersion\Feeds`); use the matching policy key instead.
- Supported value types: `DWord`, `QWord`, `String`, `ExpandString`, `MultiString`, `Binary`.
- Test new tweaks with `apply <preset> -WhatIf` first. Real runs reboot the PC, so the user runs them.

## Run
```
powershell -ExecutionPolicy Bypass -File .\winopt.ps1 status
```
