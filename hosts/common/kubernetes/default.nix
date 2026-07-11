{ ... }:
{
  imports = [
    ./cert-manager.nix
    ./cluster-issuer.nix
    ./ingress-nginx.nix
  ];
}
