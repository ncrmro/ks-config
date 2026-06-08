# Vega OS-agent RPC sidecars.
#
# These use the same git.ncrmro.com/ncrmro/vega image as the ocean dashboard,
# but override the container command to run the per-host/per-agent RPC entrypoints.
# Transcripts stay on the agent's host under that agent user's home directory;
# Vega on ocean reaches them through the pi-rpc HTTP surface.
{ config, lib, ... }:
let
  inherit (lib)
    attrNames
    concatStringsSep
    filterAttrs
    head
    listToAttrs
    mkIf
    nameValuePair
    ;

  hostName = config.networking.hostName;
  image = "git.ncrmro.com/ncrmro/vega:latest";
  rpcPort = 7700;
  portsByAgent = {
    drago = 7701;
    luce = 7702;
  };
  portFor = name: portsByAgent.${name} or 7799;
  localAgents = filterAttrs (_: agent: agent.host == hostName) config.keystone.os.agents;
  localAgentNames = attrNames localAgents;
  hasLocalAgents = localAgentNames != [ ];
  firstAgent = head localAgentNames;
  agentUser = name: "agent-${name}";
  agentHome = name: "/home/${agentUser name}";
  agentState = name: "${agentHome name}/.local/state/vega/agents/${name}";
  registryLogin = {
    enable = true;
    registry = "git.ncrmro.com";
    username = "ncrmro";
    passwordFile = "/run/agenix/vega-registry-token";
  };
  commonContainerLines = [
    "Pull=always"
  ];

  piWorkloadFor =
    name:
    nameValuePair "vega-pi-rpc-${name}" {
      enable = true;
      user = agentUser name;
      group = "agents";
      home = agentHome name;
      createHome = false;
      description = "Vega pi-rpc bridge for ${name}";
      inherit image registryLogin;
      serviceName = "vega-pi-rpc-${name}";
      containerName = "vega-pi-rpc-${name}";
      workingDir = agentHome name;
      ports = [ "0.0.0.0:${toString (portFor name)}:${toString (portFor name)}" ];
      volumes = [ "${agentHome name}:${agentHome name}" ];
      environment = {
        PI_RPC_AGENT = name;
        PI_RPC_PORT = portFor name;
        PI_RPC_BIND_HOST = "0.0.0.0";
        PI_RPC_CWD = agentState name;
        PI_RPC_SESSION_DIR = "${agentState name}/sessions";
        PI_RPC_TRANSCRIPT_DIR = "${agentState name}/transcripts";
        HOME = agentHome name;
      };
      container.extraLines = commonContainerLines ++ [
        "Exec=vega-pi-rpc"
      ];
    };

  ksAgentsRpcWorkload = nameValuePair "vega-ks-agents-rpc" {
    enable = true;
    user = agentUser firstAgent;
    group = "agents";
    home = agentHome firstAgent;
    createHome = false;
    description = "Vega host RPC daemon for OS agents on ${hostName}";
    inherit image registryLogin;
    serviceName = "vega-ks-agents-rpc";
    containerName = "vega-ks-agents-rpc";
    workingDir = agentHome firstAgent;
    ports = [ "0.0.0.0:${toString rpcPort}:${toString rpcPort}" ];
    volumes = [ "${agentHome firstAgent}:${agentHome firstAgent}" ];
    environment = {
      KS_AGENTS_RPC_HOST = hostName;
      KS_AGENTS_RPC_AGENTS = concatStringsSep "," (
        map (name: "${name}:${toString (portFor name)}") localAgentNames
      );
      KS_AGENTS_RPC_PORT = rpcPort;
      KS_AGENTS_RPC_BIND = "0.0.0.0";
      HOME = agentHome firstAgent;
    };
    container.extraLines = commonContainerLines ++ [
      "Exec=vega-ks-agents-rpc"
    ];
  };
in
mkIf hasLocalAgents {
  keystone.os.containers.workloads = listToAttrs (
    map piWorkloadFor localAgentNames ++ [ ksAgentsRpcWorkload ]
  );

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    rpcPort
  ]
  ++ map portFor localAgentNames;
}
