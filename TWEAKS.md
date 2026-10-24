# Tweaks

What winopt changes and why. Every tweak is a registry value, is backed up before it is written, and is undone by `restore`.

Presets: `basic` = taskbar, ads, lockscreen, search, performance. `full` = `basic` + effects.
Admin = needs PowerShell "Run as administrator" (HKLM or policy keys).

## Taskbar
Removes taskbar items most users never click. Cosmetic only; nothing is uninstalled.

| Id | What it does | Admin | Why |
|---|---|---|---|
| `taskbar-news` | Hides News and Interests (weather) | Yes | Constant background web content. The user key is ACL-protected on recent builds, so the policy key is used. |
| `taskbar-search-icon` | Search box becomes an icon | | Frees taskbar space; search still works. |
| `taskbar-taskview` | Hides Task View button | | `Win+Tab` still works. |
| `taskbar-cortana` | Hides Cortana button | | Cortana is retired. |
| `taskbar-meetnow` | Hides Meet Now | Yes | Skype feature, rarely used. |
| `taskbar-people` | Hides People button | | Rarely used. |
| `taskbar-ink` | Hides Windows Ink button | | Only useful with a pen. |

## Ads
Turns off suggestions, promotions and silent app installs.

| Id | What it does | Admin | Why |
|---|---|---|---|
| `ads-start-suggestions` | No app suggestions in Start | | Ads in Start menu. |
| `ads-tips` | No tips and tricks notifications | | Noise. |
| `ads-silent-apps` | Blocks silent install of promoted apps | | Stops apps like games appearing on their own. |
| `ads-settings-suggestions` | No suggested content in Settings | | Ads in Settings. |
| `ads-welcome` | No Welcome / "Get the most out of Windows" screens | | Interrupts work after updates. |
| `ads-explorer-sync` | No OneDrive/Office promos in File Explorer | | Ads in Explorer. |
| `ads-tailored` | No tailored experiences from diagnostic data | | Privacy; ads based on usage data. |
| `ads-id` | Disables advertising ID | | Privacy; stops cross-app ad tracking. |

## Lock screen
| Id | What it does | Admin | Why |
|---|---|---|---|
| `lock-facts` | No fun facts and tips on lock screen | | Ad overlay. |
| `lock-spotlight` | Disables Windows Spotlight | | Downloads images with promo links; lock screen falls back to a static picture. |

## Search
| Id | What it does | Admin | Why |
|---|---|---|---|
| `search-web` | No Bing/web results in Start search | | Faster, local-only results; less data sent online. |
| `search-web-policy` | Same, enforced by policy | Yes | `search-web` alone is ignored on some builds. |
| `search-highlights` | Disables search highlights | | Trending/ad content in the search box. |

## Performance
Only low-risk settings that the sources below agree on.

| Id | What it does | Admin | Why |
|---|---|---|---|
| `perf-menu-delay` | Menu delay from 400 ms to 100 ms | | Menus open faster. 100 instead of 0 to stay conservative. (Ten Forums, Medium) |
| `perf-startup-delay` | Removes the ~10 s delay before startup apps launch | | Apps are ready sooner after sign-in. On slow PCs boot may feel busier. (Ten Forums) |
| `perf-phonelink-bg` | Stops only Phone Link from running in background | | Saves RAM. Mail and Store keep running in background so notifications still work. |
| `perf-delivery-opt` | Stops sharing Windows updates with other PCs | Yes | Less background upload. Windows Update still works normally. (Apogee) |

## Effects (`full` only)
Saves some CPU/GPU on older or integrated-graphics PCs. Font smoothing and thumbnails are kept so text and files stay readable. (Microsoft, Netdata, PCWorld, HP)

| Id | What it does | Admin | Why |
|---|---|---|---|
| `fx-transparency` | Disables transparency | | Visual cost, no function. |
| `fx-aero-peek` | Disables Aero Peek | | Avoids accidental "see-through" windows. |
| `fx-animations` | Disables window/taskbar animations | | UI feels faster. |
| `fx-shadows` | Disables shadows under desktop icon labels | | Visual cost, no function. |
| `fx-alpha-select` | Disables translucent selection rectangle | | Visual cost, no function. |

## Not included on purpose
Suggested by some articles but rejected because they reduce security, risk data loss or can break Windows.

| Tweak | Why not |
|---|---|
| Disable Defender, Firewall, Memory Integrity, VBS | Serious security loss. |
| Disable or shrink the page file | Can cause app crashes and freezes. |
| Shorter `WaitToKillServiceTimeout` | Can corrupt files and updates on shutdown. |
| Disable DNS cache | Unsupported by Microsoft; slows or breaks networking. |
| Disable System Restore | Removes the main recovery path. |
| Disable services, SysMain/SuperFetch | Wrong choice can cripple Windows. |
| Disable all background apps | Breaks notifications for Mail, Store and other apps. |
| Hardware-accelerated GPU scheduling (HAGS) | Driver-dependent; can cause hard-to-trace GPU issues. |
| Disable Game Mode | Claimed to slow PCs; no reliable source confirms it. |
| Disable Fast Startup | Sources disagree. |
| Auto sign-in without password | Anyone with the PC gets the account. |
| Auto-enable Storage Sense | Deletes user files automatically. |
| Processor scheduling for background services | Only helps audio workstations; slows normal use. |
| High/Ultimate performance power plan | Not a registry setting; heats laptops and drains battery. |
