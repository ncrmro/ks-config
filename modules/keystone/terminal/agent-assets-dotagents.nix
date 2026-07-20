{ lib, ... }:
{
  # TODO(upstream-keystone): replace modules/terminal/agents/assets.nix's
  # consumer-flake `agents/` links with layered Dotagents/Outfitter support.
  # ks-config owns the replacement links in home-manager/common/global.
  home.activation.keystoneAgentAssetSymlinks = lib.mkForce (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ""
  );
}
