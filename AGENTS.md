# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Copilot, Cursor, etc.) working on this repository. Human contributors should read `README.md` first.

## What this project is

OmenAuto is a small set of Windows PowerShell and batch scripts that run in the background on an HP Victus / OMEN laptop and switch performance settings automatically:

- **No game running:** Quiet fan mode, GPU at normal power, fans on auto.
- **Game running:** Performance fan mode, maximum GPU power (Custom TGP + AI Boost), and full-speed fans when the NVIDIA GPU reaches `$FanOnTemp` (back to auto below `$FanOffTemp`).

It talks to the laptop BIOS directly through HP's WMI interface (`root\wmi`, class `hpqBIntM`). It does **not** need OMEN Gaming Hub, and it must **never** need a kernel driver.

## Repository layout

| File | Role |
|---|---|
| `OmenAuto.ps1` | Main watcher loop. Detects games, applies profiles, controls fans, re-applies after sleep. All user settings are at the top of this file. |
| `OmenTray.ps1` | Notification-area (tray) status icon. Read-only, runs without admin rights. Parses the last `Profil:` line of `OmenAuto.log` and checks the `Global\OmenAutoWatcher` mutex to see whether the watcher is alive. |
| `HpBios.ps1` | Thin wrapper around the HP WMI BIOS call (`Invoke-HpBios`) plus small read/write helpers. Dot-sourced by the other scripts. |
| `Kur.cmd` / `Kur.ps1` | Installer. Registers the `OmenAuto` scheduled task (at logon + on wake from sleep, highest privileges, auto-restart) and the `OmenAutoTray` task (at logon, limited rights). |
| `Kaldir.cmd` | Uninstaller. Removes both scheduled tasks and stops the watcher and the icon. |
| `Yeniden-Baslat.cmd` | Restarts the watcher after a settings change. |
| `Durum.cmd` / `Durum.ps1` | Read-only sensor test. Writes temperatures, fan levels and GPU power to `Durum.txt`. |
| `README.md` | User documentation, English first and then Turkish. |
| `LICENSE` | GPL-3.0. |

File names and user-facing messages are Turkish (`Kur` = install, `Kaldir` = uninstall, `Yeniden-Baslat` = restart, `Durum` = status). Keep that convention.

## How the BIOS interface works

Every call goes through `Invoke-HpBios` in `HpBios.ps1`:

- WMI class `hpqBDataIn` carries the request: `Sign` = `SECU` (`0x53 0x45 0x43 0x55`), `Command`, `CommandType`, `Size`, `hpqBData`.
- The method is `hpqBIOSInt<N>` on `hpqBIntM`, where `<N>` is the output size (0, 4, 128, 1024 or 4096).
- `rwReturnCode` 0 means success. Code 4 usually means the call is not supported on this model.

Commands currently used (command `0x20008` unless noted):

| Type | Purpose | Data |
|---|---|---|
| `0x1A` | Set fan / thermal mode | `FF <mode> 00 00` |
| `0x26` / `0x27` | Get / set max fan | `01` on, `00` off |
| `0x2D` | Get fan levels (CPU, GPU) | output bytes 0 and 1 |
| `0x21` / `0x22` | Get / set GPU power | `[CustomTgp, Ppab, DState, PeakTemp]` |
| `0x28` | System data (byte 3 = thermal policy version) | — |
| `0x52` (command `0x1`) | Get GPU mode (MUX) | not supported on the reference laptop |

The command codes come from [OmenMon](https://omenmon.github.io/) (GPL-3.0). Credit it whenever new codes are added.

**Verified values on the reference laptop** (HP Victus 16-d1xxx, i7-12700H, RTX 3050 Ti, thermal policy version 0):

- Fan mode: `0` = Default, `1` = Performance, `3` = Quiet.
- GPU power: normal = `0,1,1,0`; maximum = `1,1,1,0`.
- BIOS temperature (`0x23`) returns 0 and is unusable. GPU temperature comes from `nvidia-smi` instead.
- MUX / GPU mode switching and CPU power limits are not exposed.

Other models (especially thermal policy version 1) may need different values. Do not change the defaults without a measurement from real hardware.

## Hard rules

1. **Anti-cheat safety comes first.** Users run this next to kernel-level anti-cheat (Riot Vanguard). Never add anything that:
   - loads or installs a kernel driver (for example WinRing0, which OmenMon's EC access uses),
   - reads or writes another process's memory,
   - injects keyboard or mouse input or installs input hooks,
   - draws overlays on top of games.

   Game detection must stay limited to reading the process list (name and path).
2. **No unverified BIOS writes.** Only send write commands whose codes and values are documented above or confirmed on real hardware with a read-back. Add new reads first, ship writes later.
3. **Target Windows PowerShell 5.1**, not PowerShell 7. No `?.`, `??`, ternary operators or other 7-only syntax.
4. **ASCII only in `.ps1` and `.cmd` files.** PowerShell 5.1 reads BOM-less UTF-8 as ANSI, so Turkish characters break. Write Turkish without diacritics (`Baslatildi`, `sicaklik`) inside scripts. `README.md` may use full Unicode.
5. **CRLF line endings** for `.ps1` and `.cmd` (`.gitattributes` stores these files as-is, so keep CRLF in your editor).
6. **Fail safe.** Every BIOS or WMI call in the watcher loop must be inside `try/catch` and log to `OmenAuto.log` through `Write-Log`. The loop must never exit because of a single failed call.
7. **Single instance.** The watcher holds the `Global\OmenAutoWatcher` mutex. Keep that, and keep the scheduled task's `MultipleInstances IgnoreNew`.
8. **Keep it light.** The loop runs every 5 seconds forever. Do not add anything that noticeably uses CPU, disk or network.
9. **The log format is an interface.** `OmenTray.ps1` parses `yyyy-MM-dd HH:mm:ss  Profil: <Quiet|Performance> ...` and `Oyun algilandi: <process name>`. If you change these log lines in `OmenAuto.ps1`, update the parser in `OmenTray.ps1` in the same commit.
10. **No visible windows.** Scheduled tasks start PowerShell as `conhost.exe --headless powershell.exe ... -WindowStyle Hidden`. Plain `powershell.exe -WindowStyle Hidden` leaves an empty window in Alt+Tab when Windows Terminal is the default terminal on Windows 11, so do not go back to it.
11. **The tray icon stays read-only and unelevated.** It must never send BIOS commands or need administrator rights. Restarting the watcher goes through `Yeniden-Baslat.cmd`, which asks for elevation itself. A tray icon is not an overlay: it lives in the taskbar, never on top of a game.
12. **Never commit runtime files:** `*.log`, `Durum.txt`, or any personal paths, user names or e-mail addresses.

## Testing

There is no automated test suite. The scripts can only run on real HP hardware with administrator rights.

- **Syntax check (any Windows machine):**
  ```powershell
  $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content .\OmenAuto.ps1 -Raw), [ref]$null)
  ```
- **On the laptop:** run `Durum.cmd` (read-only) to confirm sensor and BIOS reads, then `Yeniden-Baslat.cmd`, and check `OmenAuto.log` for `Profil: ... (mod kodu 0, gpu kodu 0)`.
- **Tray icon:** after `Kur.cmd`, check that no "Administrator" window is listed in Alt+Tab and that the dot next to the clock is blue (red while a game runs, grey after `Kaldir.cmd` or when the watcher is stopped).
- When you cannot run on hardware, say so clearly in the pull request and list what still needs a manual check.

## Making changes

- New user settings go in the `AYARLAR` (settings) block at the top of `OmenAuto.ps1`, with a short comment.
- When behaviour, files or settings change, update **both** language sections of `README.md`.
- Keep commits small, with a clear English subject line in the imperative ("Add …", "Fix …").
- License: GPL-3.0. Do not add code under an incompatible license.
