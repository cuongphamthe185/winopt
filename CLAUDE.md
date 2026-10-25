# winopt

PowerShell CLI that hides Windows UI clutter (taskbar items, ads, suggestions) via registry, with backup and restore. Windows 10 and 11; Home, Pro, Enterprise and Education. No GUI.

## Layout
- `winopt.ps1`: entry point (`menu` (default), `list`, `status`, `backups`, `apply <preset>`, `restore`, plus `-WhatIf`, `-Only`, `-From`, `-Yes`, `-Elevate`)
- `winopt.bat`: double-click launcher; runs `winopt.ps1 menu -Elevate` (UAC prompt)
- `tweaks.json`: all tweaks (id, group, os, optional editions, name, registry values)
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
- The menu keeps the same warning, prompt and reboot as the CLI. Never add a menu path that writes without confirmation.
- Menu self-elevation only with `-Elevate`. Warn in red when the elevated user differs from the console user (changes go to that user's HKCU).
- A tweak that fails to write is undone (values and keys it created); the rest continue. If every tweak failed, delete that run's backup (it would become the "last change") and do not reboot.
- Nothing pending: print a clear message and exit without prompt or reboot. `-WhatIf` never prompts or reboots, and notes that a real run reboots.

## Windows version and edition
- Version is strict: a PC only runs tweaks whose `os` lists its version (`10` or `11`, by build >= 22000). Non-Windows-10-family versions stop with an error.
- Edition is checked before any command, read-only ones included. EditionID maps to `home` (Core*), `pro` (Professional*), `enterprise` (Enterprise*), `education` (Education*); anything else (Server, IoT, unknown) stops with an error.
- A tweak without `editions` runs on every edition. Unsupported tweaks are skipped (checked before "applied" and "needs admin"); `status` shows `n/a`.
- Skips in `apply` are one short yellow line per reason (count + hint), no id lists; `status` has a `Note` column with the reason per tweak (`needs admin`, `not for <Windows label>`).
- `restore` refuses a backup whose `os` differs from the current version or is missing, before anything else. It does not filter by edition, so anything winopt wrote stays undoable.
- `tweaks.json` is validated on load: valid `os` and `editions`, unique ids, no two tweaks writing the same value on the same version.

## Tweak conventions
- Every tweak must be reversible by `restore`; never delete a key or value that existed before.
- Prefer HKCU. Paths under HKLM or any `\Policies\` key are treated as admin-only and skipped without elevation.
- Some HKCU keys are ACL-protected on recent Windows 10 builds (e.g. `CurrentVersion\Feeds`), and on Windows 11 the UCPD driver blocks some values even for admins (e.g. `TaskbarDa` and the Widgets policy `Dsh\AllowNewsAndInterests`). Use the matching policy key where one works; otherwise leave the tweak out.
- Supported value types: `DWord`, `QWord`, `String`, `ExpandString`, `MultiString`, `Binary`.
- Test new tweaks with `apply <preset> -WhatIf` first. Real runs reboot the PC, so the user runs them.

## Run
```
powershell -ExecutionPolicy Bypass -File .\winopt.ps1 status
```
