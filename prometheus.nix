{config, lib, pkgs, ...}:

let
  statsd-exporter = {
    listenWeb = "127.0.0.1:9102";
    listenTCP = "127.0.0.1:9125";
    listenUDP = "127.0.0.1:9125";
    configFile = ./statsd-exporter-mappings.yaml;
  };
  fqdn = config.networking.fqdn;
  hostName = config.networking.hostName;
in {
  sops.secrets = {
    "prometheus_htpasswd".owner = config.services.nginx.user;
    # Contains SMTP_USER, SMTP_PASS, SMTP_HOST
    "alertmanager_env" = {};
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
      enabledCollectors = [ "systemd" ];
      # They either don't apply to us or will provide us with metrics not usefull to us
      # => Reduce amount of metrics we need to handle
      disabledCollectors = [
        "arp"
        "bcache"
        "bonding"
        "btrfs"
        "cpufreq"
        "edac"
        "entropy"
        "infiniband"
        "rapl"
        "timex"
      ];
    };

    prometheus = {
      enable = true;
      webExternalUrl = "https://${fqdn}/prometheus/";
      extraFlags = [
        # Required so we don't need to prefix the URL with /prometheus in the NGINX proxy
        "--web.route-prefix=\"/\""
      ];
      ruleFiles = [
        ./prometheus-rules.yaml
      ];
      retentionTime = "30d";
      alertmanagers = [{
        static_configs = [{
          targets = [
            "127.0.0.1:${toString config.services.prometheus.alertmanager.port}"
          ];
        }];
      }];

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [{
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
            ];
            labels.instance = hostName;
          }];
        }
        {
          job_name = "statsd";
          static_configs = [{
            targets = [
              statsd-exporter.listenWeb
            ];
            labels.instance = hostName;
          }];
        }
      ];
    };

    prometheus.alertmanager = {
      enable = true;
      # For links in notifications to be "correct"
      webExternalUrl = "https://${fqdn}/alertmanager/";
      environmentFile = config.sops.secrets."alertmanager_env".path;
      extraFlags = [
        # Required so we don't need to prefix the URL with /alertmanager in the NGINX proxy
        "--web.route-prefix=\"/\""
        # We don't need anything cluster
        "--cluster.listen-address="
      ];

      configuration = {
        global = {
          smtp_from = "Cuties.social Kuschelhaufen Monitoring <\${SMTP_USER}>";
          smtp_smarthost = "\${SMTP_HOST}:587";
          smtp_auth_username = "\${SMTP_USER}";
          smtp_auth_password = "\${SMTP_PASS}";
          smtp_hello = fqdn;
        };

        receivers = [{
          name = "mail";
          email_configs = [
            { to = "cuties@cuties.social";
              send_resolved = false; }
          ];
        }];

        route = {
          receiver = "mail";
          repeat_interval = "16h";
          group_wait = "1m";
          group_by = ["alertname" "instance"];
          routes = [
            {
              match.severiy = "critical";
              receiver = "mail";
              repeat_interval = "6h";
            }
            {
              match.severiy = "error";
              receiver = "mail";
              group_wait = "3m";
              repeat_interval = "16h";
            }
            {
              match.severiy = "warn";
              receiver = "mail";
              group_wait = "5m";
              repeat_interval = "28h";
            }
            {
              match.severiy = "info";
              receiver = "mail";
              group_wait = "10m";
              repeat_interval = "56h";
            }
          ];
        };

        inhibit_rules = [
          {
            target_matchers = ["alertname = ReducedAvailableMemory"];
            source_matchers = ["alertname =~ (Very)?LowAvailableMemory"];
            equal = ["instance"];
          }
          {
            target_matchers = ["alertname = LowAvailableMemory"];
            source_matchers = ["alertname = VeryLowAvailableMemory"];
            equal = ["instance"];
          }
          {
            target_matchers = ["alertname = ElevatedLoad"];
            source_matchers = ["alertname =~ (Very)?HighLoad"];
            equal = ["instance"];
          }
          {
            target_matchers = ["alertname = HighLoad"];
            source_matchers = ["alertname = VeryHighLoad"];
            equal = ["instance"];
          }
        ];
      };
    };

    nginx = let
      authorized_ips = [
        "127.0.0.1"
        "78.47.96.99"
        "89.58.62.171"
        "37.221.196.131"
        "::1"
        "2a0a:4cc0:1:2d7::1"
        "2a01:4f8:c17:88d8::1"
        "2a03:4000:9:f8::1"
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

        locations."/prometheus/" = authConfig // {
          proxyPass = "http://127.0.0.1:${toString config.services.prometheus.port}/";
        };

        locations."/alertmanager/" = authConfig // {
          proxyPass = "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}/";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

}
