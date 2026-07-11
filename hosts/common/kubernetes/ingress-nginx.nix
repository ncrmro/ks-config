{ ... }:
{
  services.k3s.autoDeployCharts = {
    # Ingress NGINX Controller Helm Chart: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
    ingress-nginx = {
      name = "ingress-nginx";
      repo = "https://kubernetes.github.io/ingress-nginx";
      version = "4.13.2";
      hash = "sha256-5rZUCUQ1AF6GBa+vUbko3vMhinZ7tsnJC5p/JiKllTo=";
      targetNamespace = "kube-system";
      createNamespace = false;
      values = {
        controller = {
          replicaCount = 1;
          service = {
            type = "ClusterIP";
          };
          hostNetwork = false;
          hostPort = {
            enabled = true;
            ports = {
              http = 80;
              https = 443;
            };
          };
          config = {
            "proxy-body-size" = "100m";
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
            "ncrmro.com"
          ];
        };
      };
    };
  };
}
