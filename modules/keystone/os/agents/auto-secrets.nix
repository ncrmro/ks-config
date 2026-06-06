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
  # Secret names are host-prefixed so the same logical agent secret can
  # coexist across the fleet without collisions and so each agenix entry
  # carries its routing in the filename. `host` should always be set for
  # an agent that owns secrets; the conditional keeps eval safe if it's
  # null on some test fixture.
  agentSecretName =
    name: agentCfg: suffix:
    if agentCfg.host != null then
      "${agentCfg.host}-agent-${name}-${suffix}"
    else
      "agent-${name}-${suffix}";
  mkAgentSecret =
    name: agentCfg: suffix:
    let
      secretName = agentSecretName name agentCfg suffix;
    in
    nameValuePair secretName {
      file = "${secretsRepo}/secrets/${secretName}.age";
      owner = "agent-${name}";
      mode = "0400";
    };
in
{
  config = mkIf (osCfg.enable && cfg != { } && secretsRepo != null) {
    age.secrets = listToAttrs (
      concatLists (
        mapAttrsToList (
          name: agentCfg: map (suffix: mkAgentSecret name agentCfg suffix) agentSecretSuffixes
        ) localAgents
      )
    );
  };
}
