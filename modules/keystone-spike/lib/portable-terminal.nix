# Standalone home-manager configuration for the portable devbox container
# image. Mirrors the shape of keystone's `lib.mkMacosTerminal` but for Linux,
# intended to live in `keystone/lib/templates.nix` as `mkPortableTerminal`
# after the spike is promoted.
#
# This is a function — call it from flake.nix with `pkgs.callPackage` is not
# right; instead use it as `import ./portable-terminal.nix { inherit inputs system pkgs; …}`.
#
# Once keystone#548 lands, the call site should switch to
# `extraSpecialArgs.terminalMinimal = true` (commented below) so the image
# stops carrying the full agents/mail/calendar/deepwork closure.
{
  inputs,
  system ? "x86_64-linux",
  fullName,
  email,
  stateVersion ? "25.05",
  modules ? [ ],
}:
let
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ inputs.keystone.overlays.default ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    # keystone's terminal module reads `keystoneInputs.self` for derive-on-
    # demand asset generation; pass keystone's flake through so that path
    # stays available without bind-mounts at runtime.
    keystoneInputs = { inherit (inputs) self; } // { self = inputs.keystone; };

    # TODO(promote): once ncrmro/keystone#548 merges, uncomment to switch
    # the imported terminal profile to its `terminalMinimal` form. Today
    # the image carries the full module set; the spike is functional but
    # fat (~1 GB tarball). With #548 in, the image drops to whatever the
    # ISO installer's minimal terminal closure measures.
    # terminalMinimal = true;
  };

  modules = [
    inputs.keystone.homeModules.terminal
    {
      nixpkgs.overlays = [ inputs.keystone.overlays.default ];
      home.username = "root";
      home.homeDirectory = "/root";
      home.stateVersion = stateVersion;

      keystone.terminal = {
        enable = true;
        # Pre-disable submodules that are guaranteed to fail in the container
        # (no agenix runtime, no network mail server, no DBus calendar daemon).
        # When terminalMinimal lands, these become no-ops.
        ai.enable = false;
        sandbox.enable = false;
        mail.enable = false;
        calendar.enable = false;
        contacts.enable = false;
        timer.enable = false;

        git = {
          userName = fullName;
          userEmail = email;
        };
      };
    }
  ]
  ++ modules;
}
