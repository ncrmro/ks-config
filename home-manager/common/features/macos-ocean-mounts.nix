{ pkgs, ... }:
let
  mountOceanMedia = pkgs.writeShellScriptBin "mount-ocean-media" ''
    set -euo pipefail

    host="''${OCEAN_SMB_HOST:-ocean.ncrmro.com}"
    user="''${OCEAN_SMB_USER:-timemachine}"
    share="''${OCEAN_MEDIA_SHARE:-media}"
    mountpoint="''${OCEAN_MEDIA_MOUNT:-$HOME/Mounts/ocean-media}"

    mkdir -p "$mountpoint"

    if /sbin/mount | /usr/bin/grep -q " on $mountpoint "; then
      echo "Already mounted: $mountpoint"
      exit 0
    fi

    echo "Mounting smb://$user@$host/$share at $mountpoint"
    echo "If prompted, use the ocean Time Machine SMB password and allow macOS to save it in Keychain."

    if ! /sbin/mount_smbfs "//$user@$host/$share" "$mountpoint"; then
      echo "mount_smbfs failed; opening Finder so macOS can prompt/store the credential." >&2
      /usr/bin/open "smb://$user@$host/$share"
      exit 1
    fi
  '';

  oceanTimeMachine = pkgs.writeShellScriptBin "ocean-timemachine" ''
    set -euo pipefail

    host="''${OCEAN_SMB_HOST:-ocean.ncrmro.com}"
    user="''${OCEAN_SMB_USER:-timemachine}"
    share="''${OCEAN_TIMEMACHINE_SHARE:-timemachine}"

    echo "Opening smb://$user@$host/$share"
    echo "Use the ocean Time Machine SMB password and save it in Keychain if prompted."
    /usr/bin/open "smb://$user@$host/$share"

    printf '\nOnce the share is mounted, add it as a Time Machine destination:\n\n'
    printf '  sudo tmutil setdestination -a /Volumes/%s\n\n' "$share"
    printf 'Then verify with:\n\n  tmutil destinationinfo\n\n'
  '';
in
{
  home.packages = [
    mountOceanMedia
    oceanTimeMachine
  ];

  home.file."Mounts/.keep".text = "";
}
