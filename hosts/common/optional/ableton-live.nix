# Ableton Live via Wine/Bottles with WineASIO and Yabridge for VST bridging.
# Requires keystone desktop module for PipeWire + JACK audio backend.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bottles
    wineasio
    wineWow64Packages.staging
    yabridge
    yabridgectl
  ];
}
