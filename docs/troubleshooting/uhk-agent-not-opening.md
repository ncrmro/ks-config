# UHK Agent Not Opening

## Symptoms
- UHK Agent launches but no window appears
- Process exits immediately after printing init messages
- Running from terminal shows only "init services" and "packagesDir" lines, then exits

## Root Cause

Electron's single-instance lock prevents multiple copies from running. If a previous `uhk-agent` process is still alive (e.g. from a previous login session or after a crash), new instances detect the lock and exit silently.

The lock files live in `~/.config/uhk-agent/`:
- `SingletonLock` — symlink to `<hostname>-<pid>`
- `SingletonCookie`
- `SingletonSocket`

## Diagnosis

```bash
# Check for a running uhk-agent process
pgrep -af uhk-agent

# Inspect the stale lock
ls -la ~/.config/uhk-agent/SingletonLock
# Example output: SingletonLock -> ncrmro-workstation-4858

# Verify the PID in the lock is actually alive
ps -p <pid> -o pid,state,comm
```

## Fix

Kill the stale process:

```bash
pkill -f uhk-agent
```

Then relaunch UHK Agent normally.

## Secondary Issue: Smart Macro Docs Permission Error

After fixing the singleton lock, UHK Agent may log:

```
EACCES: permission denied, unlink '.../smart-macro-docs/.../style.css'
```

This is non-fatal (the app still opens) but can be cleaned up:

```bash
rm -rf ~/.config/uhk-agent/smart-macro-docs
```

UHK Agent recreates the directory with correct permissions on next launch.

## Related Configuration

- UHK hardware enabled: `keystone.hardware.uhk.enable = true`
  - `hosts/workstation/default.nix`
  - `hosts/ncrmro-laptop/default.nix`
- UHK Agent package: `home-manager/common/features/desktop/default.nix`
- Udev rules: `/etc/udev/rules.d/50-uhk60.rules` (provided by NixOS `hardware.keyboard.uhk`)
