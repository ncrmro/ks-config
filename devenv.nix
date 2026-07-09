{ pkgs, ... }:
{
  # yq powers scripts/generate-config.sh (keystone.yaml → keystone.json).
  packages = with pkgs; [
    nixfmt-classic
    jq
    yq
  ];
}
