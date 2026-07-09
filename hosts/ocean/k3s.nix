{
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    ../common/kubernetes/zfs-localpv.nix
  ];
  # Define the K3s server token secret
  age.secrets.k3s-server-token = {
    file = "${inputs.agenix-secrets}/secrets/k3s-server-token.age";
    owner = "root";
    group = "root";
    mode = "0400";
  };
  # containerd configuration
  virtualisation.containerd = {
    enable = true;
    settings =
      let
        fullCNIPlugins = pkgs.buildEnv {
          name = "full-cni";
          paths = with pkgs; [
            cni-plugins
            cni-plugin-flannel
          ];
        };
      in
      {
        version = 2;
        plugins."io.containerd.grpc.v1.cri".containerd = {
          snapshotter = "zfs";
        };
        plugins."io.containerd.grpc.v1.cri".cni = {
          bin_dir = "${fullCNIPlugins}/bin";
          conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
        };
        # Optionally set private registry credentials here instead of using /etc/rancher/k3s/registries.yaml
        # plugins."io.containerd.grpc.v1.cri".registry.configs."registry.example.com".auth = {
        #   username = "";
        #   password = "";
        # };
      };
  };

  # k3s configuration
  networking.firewall = {
    # Pods reach NixOS-hosted services via the node address (see
    # k3s-host-services.nix Endpoints); that traffic ingresses on the CNI
    # bridge, which the firewall would otherwise drop.
    trustedInterfaces = [ "cni0" ];
    # Open K3s cluster ports only on Tailscale interface
    interfaces.tailscale0 = {
      allowedTCPPorts = [
        6443 # k3s: API server (restricted to Tailscale only)
        10250 # k3s: kubelet API
      ];
      allowedUDPPorts = [
        8472 # k3s: flannel VXLAN
      ];
    };
  };
  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.tokenFile = config.age.secrets.k3s-server-token.path;
  services.k3s.extraFlags = toString [
    "--disable=traefik" # Disable traefik to use ingress nginx instead
    "--disable=local-storage"
    "--container-runtime-endpoint=/run/containerd/containerd.sock"
    "--tls-san=ocean.mercury"
    "--tls-san=100.64.0.6"
    "--node-ip=100.64.0.6"
    "--flannel-iface=tailscale0"
    # "--debug" # Optionally add additional args to k3s
  ];
}
