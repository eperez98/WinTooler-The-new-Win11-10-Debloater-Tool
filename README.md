<div align="center">

# WinToolerV1

**Current stable: [v0.6 BETA](../../releases/tag/v0.6-beta) &nbsp;|&nbsp; Previous: [v0.5 BETA](../../releases/tag/v0.5-beta)**

A modern Windows 10/11 optimization, debloat and app management utility  
built with PowerShell 5.1 and a native WPF GUI — no .NET 6+, no runtimes, no bloat.

Made by **[ErickP (Eperez98)](https://github.com/eperez98)**  
Inspired by [ChrisTitusTech/winutil](https://github.com/christitustech/winutil)

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4?style=flat-square&logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square&logo=powershell)
![Version](https://img.shields.io/badge/version-v0.6%20BETA-orange?style=flat-square)
![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)

</div>

---

## Version History

| Version | Status | Highlights |
|---|---|---|
| **v0.6 BETA** | ✅ Current | Windows 11 ISO Downloader, full light mode fix, theme icon fix, ISO API fix, startup screen layout fix, roadmap in About tab |
| v0.5 BETA | 🔴 Superseded — known bugs | Startup screen, Dark/Light mode, EN/ES language, App Updates tab, Uninstall tab, Tweak templates, Restore Point |

> **If you are on v0.5 BETA, please update to v0.6 BETA.** See the [bug report section](#-bugs-reported-in-v05-beta--fixed-in-v06-beta) below for all issues that were patched.

---

## Screenshots

| Startup Screen | Install Apps | Tweaks |
|:-:|:-:|:-:|
| Language + Theme picker on first launch | 111 apps, category filter, live search | Templates: Minimal / Standard / Heavy |

| ISO Downloader | Repair | Dark / Light |
|:-:|:-:|:-:|
| Download Windows 11 ISOs directly from Microsoft | Async SFC+DISM, live output | One-click theme toggle in sidebar |

---

## Quick Start

> **Requirements:** Windows 10/11 · PowerShell 5.1+ · Administrator rights

1. Download and extract **WinToolerV1_v06_BETA.zip** from [Releases](../../releases)
2. Right-click **`Launch.bat`** → **Run as administrator**
3. Click **Yes** on the UAC prompt
4. Watch the CLI boot sequence complete
5. Pick your **language** (EN / ES) and **theme** (Dark / Light) on the startup screen
6. Click **Launch WinToolerV1**

<details>
<summary>Alternative — PowerShell directly</summary>

```powershell
# Open PowerShell as Administrator, cd to the folder, then:
Set-ExecutionPolicy Bypass -Scope Process -Force
.\WinToolerV1.ps1
```

</details>

---

## 🐛 Bugs Reported in v0.5 BETA — Fixed in v0.6 BETA

The following bugs were reported by users running v0.5 BETA and are **fully resolved in v0.6 BETA**.

---

### BUG-01 · Startup screen Launch button cut off at the bottom

**Reported in:** v0.5 BETA  
**Status:** ✅ Fixed in v0.6 BETA

**What happened:**  
The startup screen (language + theme picker) was displaying correctly except the **Launch WinToolerV1** button was clipped and partially hidden at the bottom of the window. Users could not click it without resizing the window, which was disabled (`ResizeMode="NoResize"`).

**Root cause:**  
The Launch button was being injected at runtime via `Add_ContentRendered`. This added a new Grid row dynamically after the window had already been sized and rendered. Because the window had a fixed `Height="560"`, the extra row was simply clipped — WPF does not auto-expand a fixed-size window for runtime content changes.

**Fix applied in v0.6:**
- Launch button moved directly into the XAML Grid at `Row="10"` so WPF accounts for it during the initial layout pass
- Added `SizeToContent="Height"` to the window so it always auto-sizes to fit all content regardless of DPI or scale settings
- Top/bottom margins tightened from `28px` to `24px`, spacer rows reduced from `20-24px` to `16px` for a cleaner fit

---

### BUG-02 · Theme toggle button showing `&#x2600;` as literal text instead of ☀ / ☽

**Reported in:** v0.5 BETA  
**Status:** ✅ Fixed in v0.6 BETA

**What happened:**  
After clicking the Dark/Light theme toggle button in the sidebar, the button label changed from the expected moon `☽` or sun `☀` icon to the raw string `&#x2600;` or `&#x263D;` displayed as plain text.

**Root cause:**  
XML/HTML entities (`&#x2600;`) are only decoded inside XAML markup by the WPF XAML parser. When the same string is assigned via PowerShell at runtime (`$ctrl["ThemeIcon"].Text = "&#x2600;"`), PowerShell treats it as a literal string — no entity decoding occurs.

**Fix applied in v0.6:**

```powershell
# Before (broken) — assigns the literal 8-character string
$ctrl["ThemeIcon"].Text = if ($dark) { "&#x2600;" } else { "&#x263D;" }

# After (fixed) — assigns the actual Unicode character
$ctrl["ThemeIcon"].Text = if ($dark) { [char]0x2600 } else { [char]0x263D }
```

---

### BUG-03 · Light mode not applying to most controls — tabs staying dark

**Reported in:** v0.5 BETA  
**Status:** ✅ Fixed in v0.6 BETA

**What happened:**  
Switching to Light mode from either the startup screen or the sidebar toggle only changed a handful of elements (window background, sidebar, page header, status bar). All tab content — cards, search boxes, comboboxes, app tiles, tweak panels, service rows, output consoles, and text labels — remained dark regardless of the selected theme.

**Root cause:**  
The `Apply-Theme` function only painted 6 hardcoded named controls. Every other WPF element kept its original dark XAML defaults. WPF does not automatically re-evaluate static resource brushes when theme state changes at runtime.

**What was hardcoded (broken):**
```powershell
$win.Background                = script:Brush $t.WinBG
$ctrl["Sidebar"].Background    = script:Brush $t.SidebarBG
$ctrl["PageHeader"].Background = script:Brush $t.Surface1
$ctrl["StatusBorder"].Background = script:Brush $t.StatusBG
$ctrl["PageTitle"].Foreground  = script:Brush $t.Text1
$ctrl["PageSubtitle"].Foreground = script:Brush $t.Text3
# Everything else: unchanged
```

**Fix applied in v0.6:**  
`Apply-Theme` now includes a recursive `Repaint-Tree` walker that traverses the entire WPF visual tree from the window root and repaints every element based on its type and `Tag` attribute:

- `Border` → card background, surface background, input background, header background
- `TextBox` → read-only consoles stay dark/green; editable inputs switch to theme colours
- `TextBlock` → muted, label, title, section variants each get the correct token
- `ComboBox` → background, foreground, border
- `ScrollViewer` → transparent background

Explicit overrides also applied to all named controls: all 9 page backgrounds, 3 search boxes, 3 ISO dropdowns, 3 output consoles, and all status/label text blocks.

---

### BUG-04 · ISO Downloader frozen on "Fetching..." — never returns a link

**Reported in:** v0.5 BETA (feature introduced in v0.6 BETA build, observed on first run)  
**Status:** ✅ Fixed in v0.6 BETA

**What happened:**  
Clicking **Get Download Link** in the ISO Downloader tab started the background job and showed "Fetching..." but never completed. The spinner ran indefinitely and no download link was returned. The output log showed:

```
Edition   : Windows 11 Home
Arch      : x64
Language  : English (United States) (en-US)
Querying Microsoft download API...
[spinner never stops]
```

**Root cause:**  
The ISO job used hardcoded Microsoft API URLs (`pageId=a8f8f489...`) to fetch session IDs and SKU lists. These endpoints now require a valid browser session cookie established by first visiting the download page — a cold API call returns an empty or malformed response with no session ID, causing all downstream calls to silently fail and the job to hang waiting for results that never come.

**Fix applied in v0.6:**  
The job was rewritten to use the correct session-cookie flow:

1. **Establish session first** — `Invoke-WebRequest` with `-SessionVariable` hits `microsoft.com/software-download/windows11` to get a live session cookie
2. **Reuse session for all API calls** — the SKU list and download link requests both use `-WebSession` with the established cookie
3. **Robust language matching** — SKU selection now matches all 15 supported locales by display name pattern rather than relying on a code suffix in the raw HTML
4. **Meaningful error messages** — HTTP 429 (rate limit), CAPTCHA detection, and page structure changes all return clear, actionable messages instead of silently hanging
5. **Fallback handling** — if exact language SKU is not found, falls back to first available SKU and notifies the user

```powershell
# Before: cold API call with no session — silently fails
$r1 = Invoke-WebRequest -Uri $sessionUrl -Headers $headers -UseBasicParsing

# After: establish real browser session first
$wr1 = Invoke-WebRequest -Uri $dlPage -UseBasicParsing -SessionVariable msSess
$wr2 = Invoke-WebRequest -Uri $skuApi -Headers $headers -WebSession $msSess -UseBasicParsing
```

> **Note:** Microsoft rate-limits automated requests. If you receive a rate-limit error, wait 2–3 minutes before trying again. If the issue persists, visit [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11) directly.

---

## Features

### Install Apps
111 apps across 10 categories — Browsers, Communications, Development, Document, Gaming, Media, Network, Productivity, Security, Utilities. Category sidebar, live search, macOS-style icon tiles, per-app install badges, progress bar, scope retry.

### Uninstall Apps
Queries `winget list` live. Search filter, checkbox multi-select, silent bulk uninstall.

### App Updates
Scanned at boot in the CLI window. Red badge shows count. Update All / Update Selected / Re-Check. Smart retry on version-mismatch (`--force`) and hash errors (cache clear).

### Tweaks
23 tweaks with Low / Medium / High risk badges. Templates: **None** (0) · **Minimal** (6) · **Standard** (13) · **Heavy** (20 — irreversible bloatware removal).

### Services
18 Windows services with live status badges. Bulk Disable / Set Manual / Re-Enable.

### Repair & Maintenance
Async SFC + DISM (live output, GUI stays responsive), Clear Temp, Flush DNS, Reset Store, Restore Point, Network Reset.

### Windows 11 ISO Downloader *(new in v0.6)*
Select edition, architecture (x64 / ARM64) and language (15 locales). Fetches download link directly from Microsoft servers. Live progress bar during download. Cancel mid-download. Open download folder.

### Windows Update
Check & install via PSWindowsUpdate. Pause 7 days. Resume.

### Dark Mode / Light Mode
Toggle with ☽ / ☀ in the sidebar at any time. All controls repaint instantly.

### English / Español
Full bilingual UI selected at startup. Every label, button, and message switches.

---

## GUI Boot Sequence

| # | Stage | Description |
|:---:|---|---|
| 01 | STA Thread Check | Auto-restarts with `-STA` if needed |
| 02 | Root Detection | 3-tier path fallback |
| 03 | Admin Verification | Exits cleanly if not elevated |
| 04 | Restore Point | Creates snapshot before any changes. Bypasses 24hr cooldown |
| 05 | winget Bootstrap | Auto-installs winget if missing |
| 06 | NuGet Provider | Silent DLL download — no interactive prompt |
| 07 | PSWindowsUpdate | Auto-installs from PSGallery |
| 08 | Execution Policy | Relaxes to `RemoteSigned` if restricted |
| 09 | .NET Framework | Detects version 4.5–4.8.1 |
| 10 | winget Sources | Refreshes package metadata |
| 11 | App Update Scan | Parses `winget upgrade`, stores results for App Updates tab |
| 12 | Module Load | Dot-sources repair, tweaks, updates functions |
| 13 | Config Load | Loads apps.json, tweaks.json, services.json |
| 14 | Startup Screen | Language + Theme picker |

---

## Project Structure

```
WinToolerV1\
  WinToolerV1.ps1        <- Main launcher + 14-step boot sequence
  Launch.bat             <- Double-click to run as Admin (-STA flag)
  README.md
  scripts\
    gui.ps1              <- Full WPF GUI + startup screen (3250+ lines)
  functions\
    tweaks.ps1           <- 23 tweak functions
    repair.ps1           <- Async SFC/DISM, DNS, temp, network, restore
    updates.ps1          <- PSWindowsUpdate integration
  config\
    apps.json            <- 111 apps across 10 categories (editable)
    tweaks.json          <- 23 tweaks with risk levels (editable)
    services.json        <- 18 Windows services (editable)
```

---

## Requirements

| | |
|---|---|
| OS | Windows 10 (build 1809+) or Windows 11 |
| PowerShell | 5.1+ (built into Windows) |
| Privileges | Administrator (UAC prompt on launch) |
| Network | Required only for Install, App Updates, ISO Downloader, and Windows Update tabs |
| winget | Auto-installed if missing |
| NuGet provider | Auto-installed via direct DLL download |
| PSWindowsUpdate | Auto-installed from PSGallery if missing |

---

## Known Limitations

- **Heavy template tweaks are irreversible.** The boot-time restore point is your safety net.
- **ISO Downloader is subject to Microsoft rate limits.** If blocked, wait 2–3 minutes and retry, or download directly from [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11).
- **Language cannot be changed after launch** without restarting. In-GUI toggle is planned for v0.7.
- **System Protection must be enabled** on C: for restore points. Group Policy may block this on managed systems.

---

## Roadmap

| Version | Planned Features |
|---|---|
| **v0.7 BETA** | Driver Updater, Startup Manager, Hosts File Editor, In-App Language Toggle, Disk Cleaner, Profile Backup |
| **v0.8 BETA** | Performance Benchmarks (WinSAT), Registry Cleaner, WSL Manager, Custom Tweak Builder, Multi-Language Expansion (FR/PT/DE/IT) |

---

## License

[GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html) — You are free to use, modify and distribute this software. Any derivative work must also be released under GPL-3.0 and remain open source.

---

<div align="center">

Made by **[ErickP (Eperez98)](https://github.com/eperez98)**  
*If this tool helped you, consider starring the repo ⭐*

</div>
