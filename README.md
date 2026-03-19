# WinTooler — V0.7 beta · Build 5035

<p align="center">
  <img src="WinToolerV1_icon.png" width="96" alt="WinTooler"/>
</p>

<p align="center">
  <b>A modern Windows 11 optimization, debloat and deployment toolkit</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-V0.7%20beta-blue?style=flat-square"/>
  <img src="https://img.shields.io/badge/build-5035-informational?style=flat-square"/>
  <img src="https://img.shields.io/badge/engine-WinTooler%20Native%20v0.7-6A0DAD?style=flat-square"/>
  <img src="https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?style=flat-square"/>
  <img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square"/>
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square"/>
</p>

---

## What is WinTooler?

WinTooler is a self-contained PowerShell WPF application for tuning, debloating and deploying Windows 10 and Windows 11. It ships a full Fluent Design GUI with real-time Light/Dark mode, runs entirely on the built-in PowerShell 5.1 engine, and requires no dependencies beyond an Administrator prompt.

Build 5035 is the most feature-complete BETA release, adding a full **ISO Creator** pipeline and an expanded **Repair** toolset on top of the core optimization modules.

---

## Feature Overview

| Module | What it does |
|---|---|
| **App Manager** | Install or uninstall 376 apps across 9 categories via winget / Chocolatey. Live search, category filter, one-click Update All. |
| **System Tweaks** | 23 registry tweaks grouped by category — Bloatware, Performance, Privacy, UI. Templates: None / Standard / Minimal / Heavy. |
| **Services Manager** | View and set 18 services to Enabled, Disabled or Manual. |
| **Repair & Maintenance** | SFC + DISM, Clear Temp, Flush DNS, Reset Windows Store, Create Restore Point, Network Reset, Delete All Restore Points. |
| **Startup Manager** | List, enable and disable registry Run keys and startup folder shortcuts. |
| **DNS Changer** | One-click switch to Cloudflare, Google, Quad9, OpenDNS, or any custom DNS pair. |
| **Profile Backup** | Export and import your tweak selections as a named JSON profile. |
| **ISO Creator** | Mount an official Windows 11 ISO, apply DISM patches, and rebuild a custom bootable ISO with optional TPM bypass, bloatware removal, driver injection, app embedding, and unattended install XML. |
| **Light / Dark Mode** | Full Windows 11 Fluent palette applied live to every surface. |
| **EN / ES Language** | English and Spanish UI with live toggle. |

---

## ISO Creator

The ISO Creator accepts any official Windows 11 ISO from Microsoft, mounts it, applies selected modifications, and rebuilds a bootable ISO using `oscdimg` (Windows ADK) or DISM.

| Modification | How it works |
|---|---|
| Bypass TPM 2.0 / Secure Boot | Mounts `boot.wim`, removes `appraiserres.dll` |
| Bypass 4 GB RAM requirement | Strips RAM check from setup constraints |
| Remove Microsoft Bloatware | Queries `DISM /Get-ProvisionedAppxPackages`, removes 24 matched packages (Teams, Xbox, News, Weather, Cortana, Clipchamp, etc.) |
| Inject Network Drivers | `DISM /Add-Driver /Recurse` against a folder of `.inf` files |
| App Packages | Select apps from the 376-app catalog — a `winget install` batch is embedded at `WinTooler\Install-Apps.bat` in the ISO root |
| Unattended Install | Injects `autounattend.xml`; if App Packages are selected, adds a `FirstLogonCommands` entry to auto-run the install script |

> Download your source ISO directly from [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11).

---

## Requirements

- Windows 10 (build 19041+) or Windows 11
- PowerShell 5.1 (built into Windows)
- **Run as Administrator**
- Internet connection for App Manager (winget)
- ISO Creator: ~8 GB free disk, DISM (built-in), optionally oscdimg (Windows ADK)

---

## Installation

No installer. Download, extract, right-click.

```
1. Download and extract WinTooler_V07beta_Build5035.zip
2. Right-click Launch.bat  →  Run as administrator
```

On first launch WinTooler bootstraps winget if absent, creates a System Restore Point, and loads all catalogs.

---

## Project Structure

```
BUILD5035/
├── WinToolerV1.ps1                      Main launcher
├── Launch.bat                           Batch launcher
├── scripts/
│   └── gui.ps1                          WPF GUI (~5000 lines)
├── functions/
│   ├── public/Invoke-Win11ISOCreator.ps1
│   ├── private/  (Get-WindowsDownload, Convert-ESDtoISO, Invoke-Oscdimg)
│   ├── repair.ps1
│   └── tweaks.ps1
└── config/
    ├── wm_apps.json    (376 apps)
    ├── tweaks.json     (23 tweaks)
    ├── services.json   (18 services)
    └── themes.json     (Light / Dark tokens)
```

---

## Roadmap

**v0.8 BETA — Power Features:** Hosts File Editor, Driver Updater, Performance Benchmarks, Registry Cleaner, WSL Manager, Custom Tweak Builder, more UI languages.

**v1.0 RC:** .msi installer, auto-update notifications, code-signed script, full OS test coverage.

---

## Known Limitations

- ISO Creator requires DISM (built-in) or Windows ADK. ADK auto-install may require a restart.
- App embedding in ISO requires winget on the target system after Windows install.
- Chocolatey requires a separate manual install; winget is primary.
- Startup Manager task disabling requires the TaskScheduler service to be running.

---

## License

GPL-3.0 © ErickP (Eperez98)
