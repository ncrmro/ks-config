# Shared agent identity declarations.
#
# Import this on every host that needs to know about agents. The `host`
# field controls WHERE feature-specific resources land:
#
#   - agent's host (e.g. workstation): SSH keys, desktop, mail client (himalaya)
#   - server host (e.g. ocean):        mail/git account provisioning (via mail.provision / git.provision)
#   - ALL importing hosts:             OS user account + home directory
#
# SSH public keys are declared in keystone.keys (modules/keystone.nix),
# not here. This file only declares agent identity and feature flags.
#
# Agenix note: secrets like agent-{name}-mail-password need recipients on
# BOTH the agent's host AND the server host. See agenix-secrets/secrets.nix.
{ inputs, pkgs, ... }:
let
  vegaPkg = inputs.vega.packages.${pkgs.stdenv.hostPlatform.system}.vega;
  ksVegaServer = {
    command = "${vegaPkg}/bin/ks-vega";
    args = [ ];
    env = {
      KS_VEGA_SERVER_URL = "https://vega.ncrmro.com";
    };
  };
in
{
  keystone.os.agents = {
    drago = {
      host = "ncrmro-workstation";
      fullName = "Drago";
      email = "drago@ncrmro.com";
      archetype = "engineer";
      capabilities = [
        "engineer"
      ];
      mail.provision = true; # provision Stalwart account on server host (ocean)
      git.provision = true; # provision Forgejo account on server host (ocean)
      dispatcher = {
        enable = false;
      };
      mcp.servers.ks-vega = ksVegaServer;
    };
    luce = {
      host = "ocean";
      fullName = "Luce";
      email = "luce@ncrmro.com";
      archetype = "product";
      default = true;
      capabilities = [
        "executive-assistant"
      ];
      mail.provision = true;
      git.provision = true;
      mcp.servers.ks-vega = ksVegaServer;
    };
  };
}
