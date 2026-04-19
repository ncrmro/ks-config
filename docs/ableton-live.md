# Ableton Live on NixOS

Ableton Live runs on this fleet via Wine inside a Bottles-managed prefix,
with WineASIO routing audio through PipeWire-JACK and Yabridge bridging
Windows VST plugins.

- NixOS module: `hosts/common/optional/ableton-live.nix`
- Hosts that import it: `ncrmro-workstation`, `ncrmro-laptop`
- Bottles runtime guide: [`bottles.md`](./bottles.md)

The module only installs packages. Ableton itself must be installed
per-user through Bottles, because the installer is a proprietary `.exe`
distributed by Ableton.

## Prerequisites

1. The keystone desktop module is active (PipeWire + JACK).
2. Bottles has been opened at least once so runners are downloaded —
   see [`bottles.md`](./bottles.md#first-run-setup).
3. You have the Ableton Live installer `.exe` from <https://www.ableton.com/>.

## Install procedure

### 1. Create the bottle

GUI: Bottles → `+ New Bottle` → environment `Application`, arch `win64`,
name `ableton`.

CLI:

    bottles-cli new --bottle-name ableton --environment application --arch win64

### 2. Run the Ableton installer

GUI: open the `ableton` bottle → `Add Shortcuts` → `Run Executable` →
select the Ableton `.exe`. Complete the wizard.

CLI:

    bottles-cli run -b ableton -e /path/to/Ableton\ Live\ <version>\ Installer.exe

Authorize the license inside Ableton as you would on Windows.

### 3. Select the WineASIO audio device

Inside Ableton: `Preferences` → `Audio` → set:

- **Driver Type**: `ASIO`
- **Audio Device**: `WineASIO`

Sample rate and buffer controls inside Ableton are advisory — the real
latency is governed by PipeWire's quantum at the system level.

### 4. Bridge VST plugins with Yabridge

After any Windows VST installer drops plugins inside the bottle:

    yabridgectl add "$HOME/.local/share/bottles/bottles/ableton/drive_c/Program Files/Common Files/VST3"
    yabridgectl add "$HOME/.local/share/bottles/bottles/ableton/drive_c/Program Files/VSTPlugins"
    yabridgectl sync

Rerun `yabridgectl sync` whenever new plugins are installed or updated.

Point Ableton at the bridged plugin directories in `Preferences` →
`Plug-Ins` if it doesn't discover them automatically.

## Launching Ableton

- GUI: open Bottles → `ableton` → click the `Ableton Live <version>` shortcut.
- CLI:

      bottles-cli run -b ableton -p "Ableton Live <version> Suite"

  (Use `bottles-cli programs -b ableton` to list the exact program name.)

## Updating Ableton

Download the new installer from Ableton's site and rerun it inside the
same bottle:

    bottles-cli run -b ableton -e /path/to/new-installer.exe

Do not create a new bottle per update — projects, preferences, and
authorization live inside the existing bottle.

## Troubleshooting

- **No audio / no device in Ableton** — confirm WineASIO is installed as
  a dependency in the bottle (`Settings` → `Dependencies` → `wineasio`),
  and that JACK is reachable: `pw-jack jack_lsp`.
- **High latency or xruns** — tune PipeWire's quantum system-wide; buffer
  settings inside Ableton alone will not fix this.
- **VST plugins missing in Ableton** — rerun `yabridgectl sync`, then
  rescan plugins in Ableton's `Preferences` → `Plug-Ins`.
- **Authorization fails** — make sure the bottle has network access
  (Bottles → bottle → `Settings` → no network sandboxing), then
  re-authorize from within Ableton.
- **Installer crashes** — verify the bottle arch matches the installer
  (`win64` for recent Ableton versions) and that the `application`
  environment was used.

## Related

- [`bottles.md`](./bottles.md) — Bottles runtime, CLI, and Yabridge basics.
- `hosts/common/optional/ableton-live.nix` — package set.
