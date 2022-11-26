{config, lib, pkgs, ...}:

{

  services = {
    prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
    };

    nginx = {
      enable = true;
      virtualHosts."${config.networking.fqdn}" = {
        enableACME = true;
        forceSSL   = true;
        locations."/node-exporter".proxyPass = "http://127.0.0.1:9100/metrics";
        locations."/node-exporter".extraConfig = "allow 78.47.96.99; allow 89.58.62.171; allow 2a0a:4cc0:1:2d7::1; allow 2a01:4f8:c17:88d8::1; deny all;";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

}
