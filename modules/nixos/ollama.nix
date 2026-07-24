# Shared Ollama service (ks-config-owned, no keystone dependency).
#
# One provider host runs the Ollama server; every fleet host is a consumer that
# automatically gets the endpoint exported as OLLAMA_HOST plus the `*-local`
# coding-harness wrappers (claude-local / opencode-local) pointing at it. This is
# wired once at the fleet level (flake.nix `shared.systemModules`) — hosts are
# NOT configured individually.
#
# Configure once:
#   local.ollama = {
#     enable = true;
#     server = { host = "ncrmro-workstation"; acceleration = "rocm";
#                models = [ "qwen3:32b" "qwen3:4b" ]; };
#     model = "qwen3:32b";   # required — used by the wrappers, no hardcoded default
#   };
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.local.ollama;

  ollamaPackage =
    if cfg.server.acceleration == "rocm" then
      pkgs.ollama-rocm
    else if cfg.server.acceleration == "cuda" then
      pkgs.ollama-cuda
    else if cfg.server.acceleration == "vulkan" then
      pkgs.ollama-vulkan
    else
      pkgs.ollama-cpu;

  isProvider = config.networking.hostName == cfg.server.host;
in
{
  options.local.ollama = {
    enable = mkEnableOption "shared Ollama service (server on the provider host, client on every host)";

    server = {
      host = mkOption {
        type = types.str;
        description = "Hostname of the fleet host that runs the Ollama server.";
        example = "ncrmro-workstation";
      };
      acceleration = mkOption {
        type = types.nullOr (
          types.enum [
            "rocm"
            "cuda"
            "vulkan"
          ]
        );
        default = null;
        description = "GPU acceleration backend for the server. null uses CPU only.";
      };
      models = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Models to pull on the server at activation.";
      };
      environmentVariables = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Extra environment variables for the server.";
        example = {
          OLLAMA_CONTEXT_LENGTH = "64000";
        };
      };
    };

    port = mkOption {
      type = types.port;
      default = 11434;
      description = "Ollama API port.";
    };

    endpoint = mkOption {
      type = types.str;
      default = "http://${cfg.server.host}:${toString cfg.port}";
      description = "API URL consumers use (exported as OLLAMA_HOST). Defaults to the provider host over the tailnet.";
    };

    model = mkOption {
      type = types.str;
      # No default on purpose — the fleet config must choose a model.
      description = "Default model for the *-local wrappers (required, not hardcoded here).";
      example = "qwen3:32b";
    };

    client.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Inject the OLLAMA_HOST env + *-local wrappers into every user on every host.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Server — only on the designated provider host.
    (mkIf isProvider {
      services.ollama = {
        enable = true;
        package = ollamaPackage;
        host = "0.0.0.0";
        port = cfg.port;
        loadModels = cfg.server.models;
        environmentVariables = cfg.server.environmentVariables;
        openFirewall = true;
      };
    })

    # Consumer — every fleet host, injected into all home-manager users.
    (mkIf cfg.client.enable {
      home-manager.sharedModules = [
        {
          home.packages = [ pkgs.ollama ];
          home.sessionVariables.OLLAMA_HOST = cfg.endpoint;
          programs.zsh.initContent = ''
            # Local Ollama coding-harness wrappers: run the llm-agents CLIs against
            # $OLLAMA_HOST with the fleet-configured model. Hosted `claude` /
            # `opencode` are unchanged.
            claude-local() {
              ANTHROPIC_BASE_URL="$OLLAMA_HOST" ANTHROPIC_AUTH_TOKEN="ollama" \
                claude --model ${cfg.model} "$@"
            }
            opencode-local() {
              OPENCODE_PROVIDER="ollama" OPENCODE_MODEL="${cfg.model}" \
                opencode "$@"
            }
          '';
        }
      ];
    })
  ]);
}
