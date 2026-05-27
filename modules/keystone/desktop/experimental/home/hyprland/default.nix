{
  config,
  lib,
  pkgs,
  ...
}: let
  hyprlandPkg = config.wayland.windowManager.hyprland.package;
  keystoneWindowSwitch = pkgs.writeShellScriptBin "keystone-window-switch" ''
    set -euo pipefail

    mapfile -t client_rows < <(
      ${hyprlandPkg}/bin/hyprctl clients -j 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r '
            map(
              select(.mapped == true)
              | {
                  address: .address,
                  workspaceName: .workspace.name,
                  className: ((.class // .initialClass // "unknown") | gsub("[\\r\\n\\t]+"; " ")),
                  windowTitle: ((.title // .initialTitle // "(untitled)") | gsub("[\\r\\n\\t]+"; " ")),
                  focusHistoryID: (.focusHistoryID // 999999)
                }
            )
            | sort_by(.focusHistoryID)
            | .[]
            | [
                .address,
                .workspaceName,
                .className,
                .windowTitle
              ]
            | @tsv
          '
    )

    if [[ ''${#client_rows[@]} -eq 0 ]]; then
      ${pkgs.libnotify}/bin/notify-send "No Hyprland windows found" -u low -t 1500
      exit 0
    fi

    declare -a addresses=()
    declare -a workspaces=()
    declare -a labels=()

    for i in "''${!client_rows[@]}"; do
      IFS=$'\t' read -r address workspace_name class_name window_title <<< "''${client_rows[$i]}"
      addresses[$i]="$address"
      workspaces[$i]="$workspace_name"
      labels[$i]="$(printf '%02d [%s] %s  %s' "$((i + 1))" "$workspace_name" "$class_name" "$window_title")"
    done

    ${pkgs.walker}/bin/walker -q >/dev/null 2>&1 || true

    selection=$(
      printf '%s\n' "''${labels[@]}" \
        | keystone-launch-walker --dmenu --placeholder "Focus window" 2>/dev/null \
        | tr -d '\r'
    ) || true

    if [[ -z "$selection" || "$selection" == "CNCLD" ]]; then
      exit 0
    fi

    index_token=''${selection%% *}
    if [[ ! "$index_token" =~ ^[0-9]+$ ]]; then
      ${pkgs.libnotify}/bin/notify-send "Window switch failed" "Could not parse selection." -u critical -t 2000
      exit 1
    fi

    index=$((10#$index_token - 1))
    if (( index < 0 || index >= ''${#addresses[@]} )); then
      ${pkgs.libnotify}/bin/notify-send "Window switch failed" "Selected window is out of range." -u critical -t 2000
      exit 1
    fi

    workspace_name="''${workspaces[$index]}"
    address="''${addresses[$index]}"

    ${hyprlandPkg}/bin/hyprctl dispatch workspace "$workspace_name" >/dev/null 2>&1 || true
    ${hyprlandPkg}/bin/hyprctl dispatch focuswindow "address:$address" >/dev/null 2>&1 || {
      ${pkgs.libnotify}/bin/notify-send "Window switch failed" "Could not focus the selected Hyprland client." -u critical -t 2000
      exit 1
    }
  '';
in {
  config = lib.mkIf config.keystone.desktop.enable {
    home.packages = [keystoneWindowSwitch];

    # CRITICAL: keystone's base bind list (modules/desktop/home/hyprland/bindings.nix)
    # uses mkDefault (override priority 1000). A normal-priority addition here
    # (e.g. lib.mkAfter, which keeps priority 100) wins outright and discards the
    # entire base list, silently killing every window-management keybind. Match
    # the base priority so this entry concatenates instead of replacing.
    wayland.windowManager.hyprland.settings.bind = lib.mkDefault [
      "$mod, slash, exec, keystone-window-switch"
    ];
  };
}
