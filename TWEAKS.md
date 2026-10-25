# Tweaks

What winopt changes and why. Every tweak is a registry value, is backed up before it is written, and is undone by `restore`.

Presets: `basic` = taskbar, ads, lockscreen, search, performance. `full` = `basic` + effects.
Win = Windows version the tweak runs on. A PC only runs the tweaks for its own version.
Admin = needs PowerShell "Run as administrator" (HKLM or policy keys).

## Taskbar
Removes taskbar items most users never click. Cosmetic only; nothing is uninstalled.

| Id | Win | What it does | Admin | Why |
|---|---|---|---|---|
| `taskbar-news` | 10 | Hides News and Interests (weather) | Yes | Constant background web content. The user key is ACL-protected on recent builds, so the policy key is used. |
| `taskbar-search-icon` | 10, 11 | Search box becomes an icon | | Frees taskbar space; search still works. |
| `taskbar-taskview` | 10, 11 | Hides Task View button | | `Win+Tab` still works. |
| `taskbar-cortana` | 10 | Hides Cortana button | | Cortana is retired. |
| `taskbar-meetnow` | 10 | Hides Meet Now | Yes | Skype feature, rarely used. |
| `taskbar-people` | 10 | Hides People button | | Rarely used. |
| `taskbar-ink` | 10 | Hides Windows Ink button | | Only useful with a pen. |

## Ads
Turns off suggestions, promotions and silent app installs.

| Id | Win | What it does | Admin | Why |
|---|---|---|---|---|
| `ads-start-suggestions` | 10, 11 | No app suggestions in Start | | Ads in Start menu. |
| `ads-start-recommendations` | 11 | No tips, shortcuts and new app recommendations in Start | | Promoted apps in the Recommended section. (PDQ, Quickfever) |
| `ads-start-account` | 11 | No account-related notifications in Start | | Promo badges on the profile icon. (Quickfever) |
| `ads-tips` | 10, 11 | No tips and tricks notifications | | Noise. |
| `ads-silent-apps` | 10, 11 | Blocks silent install of promoted apps | | Stops apps like games appearing on their own. |
| `ads-settings-suggestions` | 10, 11 | No suggested content in Settings | | Ads in Settings. |
| `ads-welcome` | 10, 11 | No Welcome / "Get the most out of Windows" screens | | Interrupts work after updates. |
| `ads-explorer-sync` | 10, 11 | No OneDrive/Office promos in File Explorer | | Ads in Explorer. |
| `ads-tailored` | 10, 11 | No tailored experiences from diagnostic data | | Privacy; ads based on usage data. |
| `ads-id` | 10, 11 | Disables advertising ID | | Privacy; stops cross-app ad tracking. |

## Lock screen
| Id | Win | What it does | Admin | Why |
|---|---|---|---|---|
| `lock-facts` | 10, 11 | No fun facts and tips on lock screen | | Ad overlay. |
| `lock-spotlight` | 10, 11 | Disables Windows Spotlight | | Downloads images with promo links; lock screen falls back to a static picture. |

## Search
| Id | Win | What it does | Admin | Why |
|---|---|---|---|---|
| `search-web` | 10 | No Bing/web results in Start search | | Faster, local-only results; less data sent online. |
| `search-web-policy` | 10, 11 | Same, enforced by policy | Yes | `search-web` alone is ignored on some Windows 10 builds; on Windows 11 the policy is the documented way. (TweakTown) |
| `search-highlights` | 10, 11 | Disables search highlights | | Trending/ad content in the search box. |

## Performance
Only low-risk settings that the sources below agree on.

| Id | Win | What it does | Admin | Why |
|---|---|---|---|---|
| `perf-menu-delay` | 10, 11 | Menu delay from 400 ms to 100 ms | | Menus open faster. 100 instead of 0 to stay conservative. (Ten Forums, Medium, TweakTown) |
| `perf-startup-delay` | 10, 11 | Removes the ~10 s delay before startup apps launch | | Apps are ready sooner after sign-in. On slow PCs boot may feel busier. (Ten Forums) |
| `perf-phonelink-bg` | 10, 11 | Stops only Phone Link from running in background | | Saves RAM. Mail and Store keep running in background so notifications still work. |
| `perf-delivery-opt` | 10, 11 | Stops sharing Windows updates with other PCs | Yes | Less background upload. Windows Update still works normally. (Apogee) |

## Effects (`full` only)
Saves some CPU/GPU on older or integrated-graphics PCs. Font smoothing and thumbnails are kept so text and files stay readable. (Microsoft, Netdata, PCWorld, HP, TweakTown)

| Id | Win | What it does | Admin | Why |
|---|---|---|---|---|
| `fx-transparency` | 10, 11 | Disables transparency | | Visual cost, no function. |
| `fx-aero-peek` | 10, 11 | Disables Aero Peek | | Avoids accidental "see-through" windows. |
| `fx-animations` | 10, 11 | Disables window/taskbar animations | | UI feels faster. |
| `fx-shadows` | 10, 11 | Disables shadows under desktop icon labels | | Visual cost, no function. |
| `fx-alpha-select` | 10, 11 | Disables translucent selection rectangle | | Visual cost, no function. |

## Enterprise and Education only
Microsoft only honors these policies on Enterprise and Education. On Home and Pro they are skipped with a warning. **Not well tested yet** (see README).

| Id | Win | Group | What it does | Admin | Why |
|---|---|---|---|---|---|
| `ads-consumer-features` | 11 | ads | Turns off Microsoft consumer experiences | Yes | Stops promoted third-party apps and suggestions. (Quickfever) |
| `ads-cloud-content` | 11 | ads | Turns off cloud optimized content | Yes | Stops cloud-sourced promotional content. (Quickfever) |
| `ads-tips-policy` | 11 | ads | Does not show Windows tips | Yes | Policy version of `ads-tips`. (Quickfever) |
| `lock-desktop-spotlight` | 11 | lockscreen | Disables Spotlight on the desktop background | Yes | Desktop Spotlight adds a Bing promo icon. (PDQ, Quickfever) |

## Not included on purpose
Suggested by some articles but rejected because they reduce security, risk data loss, can break Windows, or no longer work.

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
| Disable Widgets (Windows 11) | Both the user value `TaskbarDa` and the policy `Dsh\AllowNewsAndInterests` are locked by the UCPD driver on current builds; writing them fails even as admin. Turn Widgets off in Settings > Personalization > Taskbar. |
| Chat button `TaskbarMn` (Windows 11) | Chat was removed from current Windows 11. |
| Copilot button / `TurnOffWindowsCopilot` (Windows 11) | Copilot is now a normal app; uninstall it in Settings instead. |
| Uninstall Widgets, Copilot or other apps | Not a registry setting and not undoable by `restore`. |
