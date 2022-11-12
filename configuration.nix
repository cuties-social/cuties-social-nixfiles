{ pkgs, lib, config, nixpkgs, ... }:

# TODO: Firewall
# TODO: Emojis

let
  enableMetrics = false;
  statsd-exporter = {
    listenWeb = "127.0.0.1:9102";
    listenTCP = "127.0.0.1:9125";
    listenUDP = "127.0.0.1:9125";
    configFile = ./statsd-exporter-mappings.yaml;
  };
  mastoConfig = config.services.mastodon;
in
{
  /* imports = [
    ./hardware-config.nix
    ]; */

  system.stateVersion = "22.11";
  time.timeZone = "Europe/Berlin";
  console.keyMap = "de";

  sops = {
    defaultSopsFile = secrets/all.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets =
      let
        mastodon.owner = mastoConfig.user;
      in
      {
        "mastodon/smtp_password" = mastodon;
        "mastodon/otp_secret" = mastodon;
        "mastodon/secret_key" = mastodon;
        "mastodon/vapid/private_key" = mastodon;
        "mastodon/vapid/public_key" = mastodon;
        "root_password".neededForUsers = true;
      };
  };

  nix = {
    package = pkgs.nixVersions.stable;
    settings.auto-optimise-store = lib.mkDefault true;
    registry.nixpkgs.flake = nixpkgs;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  documentation.nixos.enable = false;
  users.users = {
    root = {
      passwordFile = config.sops.secrets."root_password".path;
    };
    f2k1de = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrvhqC/tZzpLMs/qy+1xNSVi2mfn8LXPIEhh7dcGn9e"
      ];
    };
    e1mo = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfbb4m4o89EumFjE8ichX03CC/mWry0JYaz91HKVJPb e1mo"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID9x/kL2fFqQSEyFvdEgiM2UKYAZyV1oct9alS6mweVa e1mo (ssh_0x6D617FD0A85BAADA)"
      ];
    };
  };
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ] ++ config.services.openssh.ports;
  };

  networking.hostName = "kuschelhaufen";
  networking.domain = "cuties.social";

  security.acme = {
    acceptTerms = true;
    defaults.email = "cuties@cuties.social";
  };

  services.mastodon =
    let
      secrets = config.sops.secrets;
    in
    {
      enable = true;
      localDomain = "cuties.social";
      configureNginx = true;
      automaticMigrations = false;

      secretKeyBaseFile = secrets."mastodon/secret_key".path;
      vapidPrivateKeyFile = secrets."mastodon/vapid/private_key".path;
      vapidPublicKeyFile = secrets."mastodon/vapid/public_key".path;
      otpSecretFile = secrets."mastodon/otp_secret".path;

      elasticsearch = {
        port = config.services.elasticsearch.port;
        host = "127.0.0.1";
      };
      smtp = {
        createLocally = false;
        port = 465;
        host = "telesto.host.static.dont-break.it";
        user = "mastodon@cuties.social";
        fromAddress = "mastodon@cuties.social";
        authenticate = true;
        passwordFile = secrets."mastodon/smtp_password".path;
      };

      extraConfig = {
        MAX_TOOT_CHARS = "5000";
        MIN_POLL_OPTIONS = "1";
        MAX_POLL_OPTIONS = "10";
        MAX_DISPLAY_NAME_CHARS = "100";
        MAX_BIO_CHARS = "1000";
        MAX_PROFILE_FIELDS = "10";
      };
    };

  systemd.services.mastodon-import-emojis = {
    after = [ "mastodon-web.service" ];
    script = ''
      categories=$(ls ${pkgs.customEmojis})

      for category in $categories; do
        category_name="''${category##*/}"
        category_name_arg="--category \"''${category_name}\""
        if [[ "$category_name" == "undefined" ]]; then
          category_name_arg=""
        fi

        echo "Importing ''${category_name} from ''${category} with ''${category_name_arg}";

        ${mastoConfig.package}/bin/tootctl emoji import ''${category} --overwrite ''${category_name_arg}
      done
    '';
    environment = config.systemd.services.mastodon-init-dirs.environment;
    serviceConfig = {
      Type = "oneshot";

      WorkingDirectory = mastoConfig.package;
      User = mastoConfig.user;
      Group = mastoConfig.group;

      # Comming from
      # https://github.com/NixOS/nixpkgs/blob/nixos-22.05/nixos/modules/services/web-apps/mastodon.nix#L45-L86

      # State directory and mode
      StateDirectory = "mastodon";
      StateDirectoryMode = "0750";
      # Logs directory and mode
      LogsDirectory = "mastodon";
      LogsDirectoryMode = "0750";
      ProcSubset = "pid";
      ProtectProc = "invisible";
      # Access write directories
      UMask = "0027";
      # Capabilities
      CapabilityBoundingSet = "";
      # Security
      NoNewPrivileges = true;
      # Sandboxing
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = false;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      PrivateMounts = true;
      # System Call Filtering
      SystemCallArchitectures = "native";
      SysCallFilter = [ "@chown" "pipe" "pipe2" ];

      EnvironmentFile = "/var/lib/mastodon/.secrets_env";
    };
  };

  services.elasticsearch = {
    package = pkgs.elasticsearch7;
    enable = true;
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

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  services.nginx.virtualHosts."${config.services.mastodon.localDomain}".locations =
    let
      metricsAllowedIPs = [ "10.0.0.0/8" ]; # Placeholder so we can change it in the future
      authConfig = ''
        allow ${lib.concatStringsSep  "; \n" metricsAllowedIPs}
        deny all;
      '';
    in
    {
      "/metrics/node" = {
        proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.node.port}/metrics";
        extraConfig = authConfig;
      };
      "/metrics/statsd" = {
        proxyPass = "http://${statsd-exporter.listenWeb}/metrics";
        extraConfig = authConfig;
      };
    };
}
