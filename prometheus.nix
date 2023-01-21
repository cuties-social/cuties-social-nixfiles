{config, lib, pkgs, ...}:

let
  statsd-exporter = {
    listenWeb = "127.0.0.1:9102";
    listenTCP = "127.0.0.1:9125";
    listenUDP = "127.0.0.1:9125";
    configFile = ./statsd-exporter-mappings.yaml;
  };
in {
  sops.secrets."prometheus_htpasswd" = {
    owner = config.services.nginx.user;
  };

  systemd.services."prometheus-statsd-exporter" = {
    wantedBy = [
      "multi-user.target"
      "mastodon-web.service"
    ];
    serviceConfig = {
      DynamicUser = true;
      RuntimeDirectory = "prometheus-statsd-exporter";
      ExecStart = ''${pkgs.prometheus-statsd-exporter}/bin/statsd_exporter
        --web.listen-address="${statsd-exporter.listenWeb}"
        --statsd.listen-tcp="${statsd-exporter.listenTCP}"
        --statsd.listen-udp="${statsd-exporter.listenUDP}"
        --statsd.mapping-config=${statsd-exporter.configFile}
      '';
    };
  };

  services = {
    mastodon.extraConfig.STATSD_ADDR = statsd-exporter.listenUDP;

    prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
    };

    nginx = let
      authorized_ips = [
        "127.0.0.1"
        "78.47.96.99"
        "89.58.62.171"
        "::1"
        "2a0a:4cc0:1:2d7::1"
        "2a01:4f8:c17:88d8::1"
      ];
      authConfig = {
        basicAuthFile = config.sops.secrets."prometheus_htpasswd".path;
        extraConfig = ''
          satisfy any;
          ${lib.concatMapStringsSep "\n" (ip: "allow ${ip};") authorized_ips}
          deny all;
        '';
      };
    in {
      enable = true;
      virtualHosts."${config.networking.fqdn}" = {
        enableACME = true;
        forceSSL   = true;

        locations."/metrics/node" = authConfig // {
          proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.node.port}/metrics";
        };

        locations."/metrics/statsd" = authConfig // {
          proxyPass = "http://${toString statsd-exporter.listenWeb}/metrics";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

}
