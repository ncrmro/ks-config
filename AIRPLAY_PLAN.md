# Keystone AirPlay Module Plan [COMPLETED]

## Current Situation (Resolved)
- **Status**: Migrated to Keystone OS module.
- **New Module**: `../keystone/modules/os/airplay.nix`
- **Configuration**:
  - **Dynamic Naming**: Configurable via `keystone.os.services.airplay.name`.
  - **Firewall**: Automatically managed via `openFirewall` option.
  - **Audio Backend**: PulseAudio (PipeWire compatible).
  - **Dependencies**: `nqptp` and `shairport-sync` services unified in the module.

## Summary of Changes
1. Created `keystone.os.services.airplay` module in Keystone submodule.
2. Integrated module into `operating-system` module export.
3. Migrated `ncrmro-workstation` to use the new module (named "Workstation Speakers").
4. Removed AirPlay from `ncrmro-laptop`.
5. Deleted the old legacy configuration `hosts/common/optional/shairport-sync.nix`.
