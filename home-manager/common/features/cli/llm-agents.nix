# AI coding agents — self-contained, installed directly from ks-config's
# `llm-agents` flake input (numtide/llm-agents.nix, pinned in flake.nix and
# bumped with `nix flake update llm-agents`).
#
# Keystone is deprecating its own bundled agent packages, so we turn keystone's
# installer off (keystone.terminal.ai.enable) — otherwise its claude-code and
# ours would both put `bin/claude` in the profile and home-manager would error
# on the collision. These are the only agent copies on PATH.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system} or { };
  pick = name: lib.optional (agents ? ${name}) agents.${name};
in
{
  keystone.terminal.ai.enable = lib.mkForce false;

  home.packages =
    (pick "claude-code")
    ++ (pick "gemini-cli")
    ++ (pick "codex")
    ++ (pick "opencode");
}
