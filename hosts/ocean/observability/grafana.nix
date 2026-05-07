{
  config,
  pkgs,
  inputs,
  ...
}:
{
  keystone.server.services.grafana.enable = true;

  age.secrets.grafana-secret-key = {
    file = "${inputs.agenix-secrets}/secrets/grafana-secret-key.age";
    owner = "grafana";
    mode = "0400";
  };

  services.grafana.settings = {
    security.secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
    smtp = {
      enabled = true;
      host = "mail.ncrmro.com:587";
      from_address = "grafana@ncrmro.com";
      user = "grafana";
      password = "$__file{${config.age.secrets.grafana-smtp-password.path}}";
    };
  };

  services.grafana.provision.dashboards.settings.providers = [
    {
      name = "nixos-dashboards";
      options.path = pkgs.linkFarm "grafana-dashboards" [
        {
          name = "node-exporter-full.json";
          path = pkgs.fetchurl {
            url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
            hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
          };
        }
        {
          name = "ox-node.json";
          path = ./dashboards/ox-node.json;
        }
      ];
    }
  ];

  # Grafana API token for MCP server
  age.secrets.grafana-api-token = {
    file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
    owner = "root";
    mode = "0400";
  };

  # MCP server for Grafana
  systemd.services.mcp-grafana = {
    description = "MCP server for Grafana";
    wantedBy = [ "multi-user.target" ];
    after = [ "grafana.service" ];
    serviceConfig = {
      Restart = "on-failure";
      DynamicUser = true;
      LoadCredential = "grafana-token:${config.age.secrets.grafana-api-token.path}";
    };
    script = ''
      export GRAFANA_URL="http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}"
      export GRAFANA_SERVICE_ACCOUNT_TOKEN="$(cat $CREDENTIALS_DIRECTORY/grafana-token)"
      exec ${pkgs.mcp-grafana}/bin/mcp-grafana -transport sse -address 127.0.0.1:8090
    '';
  };

  services.nginx.virtualHosts."mcp-grafana.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = ''
      allow 100.64.0.0/10;
      allow fd7a:115c:a1e0::/48;
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:8090";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;
      '';
    };
  };
}
