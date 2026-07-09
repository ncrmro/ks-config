{ ... }:
{
  services.k3s.autoDeployCharts = {
    # Ingress NGINX Controller Helm Chart: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
    # NixOS nginx is the front-end on 80/443, forwarding K8s traffic to these internal ports
    ingress-nginx = {
      name = "ingress-nginx";
      repo = "https://kubernetes.github.io/ingress-nginx";
      version = "4.13.2";
      hash = "sha256-5rZUCUQ1AF6GBa+vUbko3vMhinZ7tsnJC5p/JiKllTo=";
      targetNamespace = "kube-system";
      createNamespace = false;
      values = {
        controller = {
          replicaCount = 2;
          service = {
            type = "ClusterIP";
          };
          hostNetwork = false;
          hostPort = {
            enabled = true;
            ports = {
              http = 8080;
              https = 8443;
            };
          };
          config = {
            "proxy-body-size" = "100m";
            # Trust X-Forwarded-* headers from NixOS nginx (localhost)
            "use-forwarded-headers" = "true";
            "compute-full-forwarded-for" = "true";
            # Trust forwarded headers from the NixOS nginx front. Its
            # connections to the ingress hostPort arrive SNAT'd to the CNI
            # bridge address, so the pod CIDR must be trusted alongside
            # loopback for real-IP restoration (whitelist-source-range
            # enforcement depends on this).
            "proxy-real-ip-cidr" = "127.0.0.0/8,10.42.0.0/16";
          };
          watchIngressWithoutClass = true;
          ingressClassResource = {
            name = "nginx";
            enabled = true;
            default = true;
          };
          extraArgs = {
            "default-ssl-certificate" = "kube-system/wildcard-ncrmro-com-tls";
          };
        };
      };
    };
  };

  # Wildcard certificate for *.ncrmro.com domain
  services.k3s.manifests = {
    wildcard-certificate = {
      enable = true;
      target = "wildcard-ncrmro-com-certificate.yaml";
      content = {
        apiVersion = "cert-manager.io/v1";
        kind = "Certificate";
        metadata = {
          name = "wildcard-ncrmro-com";
          namespace = "kube-system";
        };
        spec = {
          secretName = "wildcard-ncrmro-com-tls";
          issuerRef = {
            name = "letsencrypt-cloudflare";
            kind = "ClusterIssuer";
          };
          dnsNames = [
            "*.ncrmro.com"
            "*.home.ncrmro.com"
            "ncrmro.com"
          ];
        };
      };
    };
  };
}
