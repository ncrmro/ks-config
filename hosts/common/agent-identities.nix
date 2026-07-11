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
{ ... }:
{
  # OS agents are currently disabled fleet-wide. Keystone's agent modules key
  # off `keystone.os.agents != { }`, so an empty set removes agent users,
  # services, secrets, and mail/git provisioning. Uncomment to re-enable.
  keystone.os.agents = { };
  /*
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
      # Outfitter profiles now live under agents/outfitter; do not wrap agent
      # Pi launches with the retired ApplePi profile runner.
      applepi.enable = false;
      # Agents only need Chrome DevTools access, not a viewable desktop.
      desktop.enable = false;
      chrome = {
        mode = "headless";
        healthCheck = {
          interval = "30min";
          probeMcp = false;
        };
      };
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
      # Outfitter profiles now live under agents/outfitter; do not wrap agent
      # Pi launches with the retired ApplePi profile runner.
      applepi.enable = false;
    };
  };
  */
}
