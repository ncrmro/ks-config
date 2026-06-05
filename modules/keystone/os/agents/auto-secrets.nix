# Auto-declare per-agent agenix secrets that keystone's agent modules
# currently only assert on. Mirrors the existing pattern in
# keystone/modules/os/agents/perception.nix (the immich-api-key block).
#
# Staged here per modules/keystone/AGENTS.md. Once the same logic lands
# inside keystone proper and flake.lock is bumped, delete this file and
# remove its import from modules/keystone/os.nix.
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    filterAttrs
    listToAttrs
    concatLists
    mapAttrsToList
    nameValuePair
    ;
  osCfg = config.keystone.os;
  cfg = osCfg.agents;
  secretsRepo = config.keystone.secrets.repo;
  localAgents = filterAttrs (
    _: agentCfg: agentCfg.host == null || agentCfg.host == config.networking.hostName
  ) cfg;
  agentSecretSuffixes = [
    "ssh-key"
    "ssh-passphrase"
    "mail-password"
    "bitwarden-password"
    "tailscale-auth-key"
  ];
  mkAgentSecret =
    name: suffix:
    nameValuePair "agent-${name}-${suffix}" {
      file = "${secretsRepo}/secrets/agent-${name}-${suffix}.age";
      owner = "agent-${name}";
      mode = "0400";
    };
in
{
  config = mkIf (osCfg.enable && cfg != { } && secretsRepo != null) {
    age.secrets = listToAttrs (
      concatLists (
        mapAttrsToList (name: _: map (suffix: mkAgentSecret name suffix) agentSecretSuffixes) localAgents
      )
    );
  };
}
