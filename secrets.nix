let
  # SSH public keys for users and systems
  users = {
    ncrmro = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOyrDBVcGK+pUZOTUA7MLoD5vYK/kaPF6TNNyoDmwNl2 ncrmro@ncrmro-laptop-fw7k";
    ncrmro-workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiFUbcDdzBGNgo7GdRvuRvZ9Yf195pIm2jbiM0uJwW0 ncrmro@ncrmro-workstation";
    ncrmro-ocean = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEE6cFSyJoiaURB7+961zETflBNPJUZszH9xyowzbpNu ncrmro@ocean";
  };

  systems = {
    ocean = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7Oo3b71YDnN2i3vOsXrE4PFhmByjCIW5YtH7VkrTtC";
    maia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtdLpd4fI4U4JSQeo0z/m2KdB+qAGyURSPko7/1BCIa";
    mercury = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK80XMxx82fVvZgZ5djaXKvy1fRriQwkO4OAtf65ElhU";
    workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMalqC7xISpPwp7pPHcx8Qc3eiA1LOqJAmflFlHH0oCw";
    laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdFyolB6Fb6z8r+38nsqDig9II1D400COykJPUs2G18";
    # Get with: ssh ocean "cat /var/lib/microvms/agent-drago/etc/ssh/ssh_host_ed25519_key.pub"
    agent-drago = "ssh-ed25519 PLACEHOLDER_GET_KEY_FROM_VM";
  };

  # Convenience aliases for common key combinations
  adminKeys = [
    users.ncrmro
    users.ncrmro-workstation
  ];
  desktops = [
    systems.workstation
    systems.laptop
  ];
  k3sServers = [ systems.ocean ]; # Only server nodes
  k3sAgents = [ systems.maia ]; # Only agent nodes
in
{
  # K3s server token - accessible by admin and K3s server nodes only
  "secrets/k3s-server-token.age".publicKeys = adminKeys ++ k3sServers;

  # K3s agent token - accessible by admin and K3s agent nodes only
  "secrets/k3s-agent-token.age".publicKeys = adminKeys ++ k3sAgents;

  # Cloudflare API token for ACME DNS-01 challenge
  "secrets/cloudflare-api-token.age".publicKeys = adminKeys ++ [
    systems.mercury
    systems.ocean
  ];

  # SABnzbd usenet server configuration (contains credentials)
  "secrets/sabnzbd-servers.age".publicKeys = adminKeys ++ [ systems.ocean ];

  # Samba Time Machine password
  "secrets/samba-timemachine-password.age".publicKeys = adminKeys ++ [ systems.ocean ];

  # Stalwart admin password (ocean mail server)
  "secrets/stalwart-admin-password.age".publicKeys = adminKeys ++ [
    users.ncrmro-ocean
    systems.ocean
  ];

  # Stalwart mail user password (for himalaya client on desktops)
  "secrets/stalwart-mail-ncrmro-password.age".publicKeys =
    adminKeys ++ [ users.ncrmro-ocean ] ++ desktops;

  # Agent drago mail password (for himalaya client on agent-drago)
  # TODO: add systems.agent-drago back once the real host key replaces the placeholder
  "secrets/agent-drago-mail-password.age".publicKeys = adminKeys ++ [ users.ncrmro-ocean ];

  # Vega runtime config (Stalwart CalDAV/CardDAV creds + room for future
  # tokens). Single yaml file read at process boot by code/server/src/config.ts.
  # Exposed to the non-root vega service via systemd LoadCredential. See
  # docs/specs/007-stalwart-integration/ for the convention.
  "secrets/vega-config.yaml.age".publicKeys = adminKeys ++ [ systems.ocean ];

  # Miniflux admin credentials (ocean RSS reader)
  "secrets/miniflux-admin.age".publicKeys = adminKeys ++ [ systems.ocean ];

  # Grafana API token for MCP server
  "secrets/grafana-api-token.age".publicKeys = adminKeys ++ [ systems.ocean ] ++ desktops;

  # Grafana SMTP password (for alerting via Stalwart)
  "secrets/grafana-smtp-password.age".publicKeys = adminKeys ++ [ systems.ocean ];

  # Cliflux config (Miniflux CLI client config with API key, for desktops)
  "secrets/cliflux-config.age".publicKeys = adminKeys ++ desktops;

  # GitHub agents token (user-readable; consumed by keystone.terminal.github)
  "secrets/github-agents-token.age".publicKeys = adminKeys ++ desktops;

  # GitHub token for the nix daemon — root-readable, system-key recipients.
  # Consumed by keystone.os.githubTokenNix; see conventions/tool.nix.md.
  "secrets/nix-github-token.age".publicKeys = adminKeys ++ desktops;
}
