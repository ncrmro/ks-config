# Bottles on NixOS

Bottles is a Wine prefix manager used here to run Windows audio software
(notably Ableton Live) with WineASIO routing into PipeWire-JACK.

The NixOS module lives at `hosts/common/optional/ableton-live.nix` and
provides `bottles`, `wineWow64Packages.staging`, `wineasio`, `yabridge`, and
`yabridgectl`. PipeWire + JACK is handled by keystone's desktop module.

## First-run setup

On first launch Bottles needs to download Wine runners, DXVK, and supporting
components. This MUST be done through the GUI at least once — the CLI runs
in forced-offline mode and cannot fetch runners itself.

1. Launch Bottles from the application menu.
2. Let the onboarding dialog complete the runner and dependency download.
3. Close Bottles once the download finishes.

After this, `bottles-cli` can operate offline against the downloaded runners.

## Creating a bottle

GUI flow:

1. Open Bottles → `+ New Bottle`.
2. Pick the environment:
   - **Application** — general-purpose Windows apps (use this for Ableton).
   - **Gaming** — preconfigured with DXVK, esync, gamescope friendly settings.
   - **Custom** — start from a YAML definition.
3. Set the bottle name and architecture (`win64` unless the installer is 32-bit).
4. Click `Create`.

CLI equivalent:

    bottles-cli new \
      --bottle-name <name> \
      --environment application \
      --arch win64

## Installing a Windows program

1. In the bottle view, `Add Shortcuts` → `Run Executable` and pick the `.exe`.
2. The installer runs inside the bottle; complete the wizard normally.
3. Installed shortcuts appear under `Programs` in the bottle.

CLI:

    bottles-cli run -b <bottle-name> -e /path/to/installer.exe

## Bottle filesystem layout

Bottles live under `~/.local/share/bottles/bottles/<name>/`. The Windows
`C:` drive is `<bottle>/drive_c/`. VST plugin install paths are typically:

- `drive_c/Program Files/Common Files/VST3/`
- `drive_c/Program Files/VSTPlugins/`
- `drive_c/Program Files (x86)/VSTPlugins/`

## WineASIO

WineASIO exposes a Windows ASIO driver backed by JACK (routed through
PipeWire on this system). Enable it per-bottle:

1. In the bottle, open `Settings` → `Dependencies` and ensure `wineasio`
   is listed. If not, `Dependencies` → install `wineasio`.
2. Inside the Windows app (e.g., Ableton), select **WineASIO** as the
   audio device.

Latency is controlled by PipeWire's quantum — not by the Windows app's
buffer-size setting.

## Yabridge for VST plugins

Yabridge bridges Windows VST/VST3/CLAP plugins into Linux-native hosts, but
it's also used here to expose plugins installed in Bottles to Ableton (and
to any Linux DAW).

    yabridgectl add "$HOME/.local/share/bottles/bottles/<name>/drive_c/Program Files/Common Files/VST3"
    yabridgectl add "$HOME/.local/share/bottles/bottles/<name>/drive_c/Program Files/VSTPlugins"
    yabridgectl sync

Re-run `yabridgectl sync` after installing new plugins.

List configured directories and status:

    yabridgectl list
    yabridgectl status

## Troubleshooting

- **`bottles-cli` fails with `Data file not found`** — GUI has never been
  opened. Launch Bottles once to initialize `~/.local/share/bottles/`.
- **No WineASIO device in the Windows app** — confirm JACK is running
  (`pw-jack jack_lsp`) and that `wineasio` is installed as a dependency in
  that bottle.
- **Crackles / xruns** — raise PipeWire's quantum. See the keystone
  desktop/audio module for the system-wide setting.
- **`yabridgectl sync` reports missing files** — rerun after the Windows
  installer has actually placed the `.dll`/`.vst3` files in the target
  directory.
