{ inputs, ... }:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
in
{
  imports = [ inputs.vega.nixosModules.default ];

  services.vega = {
    enable = true;
    bindHost = "127.0.0.1";
    port = 17878;
    # The browser is reached at https://vega.ncrmro.com via nginx; the
    # SSR sees the proxy origin (http://127.0.0.1:17878) and otherwise
    # bakes that into the rendered HTML as the API base. Override with
    # the public URL so client-side fetches go to the right place.
    environment = {
      PUBLIC_BROWSER_SERVER_URL = "https://vega.ncrmro.com";
      # Ocean has no GPU. Route ollama traffic to ncrmro-workstation's
      # tailnet ollama (RX 9070 XT, hosts nemotron-3-nano:4b + qwen3:32b
      # + friends). URL must end in /v1 — pi-ai uses the OpenAI-compat
      # surface, not the native /api/* routes. See vega/server/src/routes/agent.ts
      # ModelRegistry.registerProvider override.
      OLLAMA_BASE_URL = "http://ncrmro-workstation:11434/v1";
    };
  };

  services.nginx.virtualHosts."vega.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:17878";
      proxyWebsockets = true;
    };
  };
}
