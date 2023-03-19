{ pkgs, lib, config, nixpkgs, ... }:

let
  enableMetrics = false;
  mastoConfig = config.services.mastodon;
in
{
  imports = [
    ./hardware-config.nix
    ./prometheus.nix
    ./modules/restic-backups.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "22.11";
  time.timeZone = "Europe/Berlin";
  console.keyMap = "de";

  networking = {
    hostName = "kuschelhaufen";
    domain = "cuties.social";

    defaultGateway6 = {
      address = "fe80::1";
      interface = "ens3";
    };
    defaultGateway = {
      address = "89.58.60.1";
      interface = "ens3";
    };

    interfaces.ens3 = {
      # Netcup reccomends disabling DHCP for IPv4
      useDHCP = false;

      ipv6.addresses = [{
        address = "2a0a:4cc0:1:271::1";
        prefixLength = 64;
      }];

      ipv4.addresses = [{
        address = "89.58.61.90";
        prefixLength = 22;
      }];
    };

    nameservers = [
      # Clownflare
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
      "1.1.1.1"
      "1.0.0.1"
      # Goggle
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
      "8.8.8.8"
      "8.8.4.4"
    ];

    firewall = {
      enable = true;
      rejectPackets = true; # Makes debugging easier
      allowedTCPPorts = [ 80 443 ] ++ config.services.openssh.ports;
    };
  };

  # Advised in the netcup docs
  # https://www.netcup-wiki.de/wiki/Zus%C3%A4tzliche_IP_Adresse_konfigurieren
  boot.kernel.sysctl = {
    "net.ipv6.conf.default.accept_ra" = 0;
    "net.ipv6.conf.default.autoconf"  = 0;
    "net.ipv6.conf.all.accept_ra"     = 0;
    "net.ipv6.conf.all.autoconf"      = 0;
    "net.ipv6.conf.ens3.accept_ra"    = 0;
    "net.ipv6.conf.ens3.autoconf"     = 0;
  };

  environment.systemPackages = with pkgs; [
    htop
    nano
    vim
    tmux
    rsync
    curl
    wget
    bat
    fd
    ripgrep
    neofetch
  ];

  sops = {
    defaultSopsFile = secrets/all.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets =
      let
        mastodon.owner = mastoConfig.user;
      in {
        "mastodon/smtp_password" = mastodon;
        "mastodon/otp_secret" = mastodon;
        "mastodon/secret_key" = mastodon;
        "mastodon/vapid/private_key" = mastodon;
        "mastodon/vapid/public_key" = mastodon;
        "kuschelhaufen-at-cuties-social" = {};
        "restic-repo-password" = mastodon;
        "restic-server-jules" = mastodon;
        "root_password".neededForUsers = true;
      };
  };

  nix = {
    package = pkgs.nixVersions.stable;
    settings.auto-optimise-store = lib.mkDefault true;
    settings.trusted-users = [ "root" "@wheel" ];
    registry.nixpkgs.flake = nixpkgs;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  documentation.nixos.enable = false;
  users.motd = ''
                _   _
      ___ _   _| |_(_) ___  ___
    / __| | | | __| |/ _ \/ __|
    | (__| |_| | |_| |  __/\__ \
    \___|\__,_|\__|_|\___||___/

                          _       _
            ___  ___   ___(_) __ _| |
          / __|/ _ \ / __| |/ _` | |
          _\__ \ (_) | (__| | (_| | |
        (_)___/\___/ \___|_|\__,_|_|

                                              .
                                    ;.  .,   ,x:
                                cd'NX. kX :OK,
                              ;dkkk,Xocl,o0K0
                            ckkxdkk;,ol.0KKo,
                ..',,',cloookkd;d:;c,.c:l:c;
              'clllllll,',;lkkl,:cllll;llll:c.
            .lllll;;;;;;',::::llllllc,:cll,,;'
        .:c,llllllllllll:,lllllllllc:,cllllll,
        :kkd,lllllllllllll:;lll,llllllllllllllll.
      .lkkk,llllllllllllll;:ll:'llllllllllllcl:l
    'kkkkk::lll,:llllll:' :cll:';;;;;;;';:cc:,
    :kkkkkkocccd,llllc;cll;..'lllllllll,.....'.
      kkkkkkkkkkx                      ..'.
        xl. ol

    ${config.networking.fqdn}
  '';

  users.users = {
    root = {
      passwordFile = config.sops.secrets."root_password".path;
    };
    isa = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrvhqC/tZzpLMs/qy+1xNSVi2mfn8LXPIEhh7dcGn9e"
      ];
    };
    e1mo = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
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

  security.acme = {
    acceptTerms = true;
    defaults.email = "cuties@cuties.social";
  };

  services.mastodon =
    let
      secrets = config.sops.secrets;
    in {
      enable = true;
      localDomain = "cuties.social";
      configureNginx = true;
      automaticMigrations = true;

      secretKeyBaseFile = secrets."mastodon/secret_key".path;
      vapidPrivateKeyFile = secrets."mastodon/vapid/private_key".path;
      vapidPublicKeyFile = secrets."mastodon/vapid/public_key".path;
      otpSecretFile = secrets."mastodon/otp_secret".path;

      mediaAutoRemove = {
        enable = true;
        olderThanDays = 21;
      };

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

        SMTP_ENABLE_STARTTLS_AUTO = "false";
        SMTP_ENABLE_STARTTLS = "never";
        SMTP_TLS = "true";
      };
    };

  systemd.services.mastodon-import-emojis = {
    description = "Import custom emojis into mastodon";
    after = [ "mastodon-web.service" ];
    script = ''
      for category in ${pkgs.customEmojis}/*; do
        filename=''${category##*/}
        category_name="''${filename%%.*}"
        category_name_arg="--category \"''${category_name}\""
        if [ "$category_name" = "uncategorized" ]; then
          category_name_arg=""
        fi

        echo "Importing ''${filename} from ''${category} with \"''${category_name_arg}\"";

        ${mastoConfig.package}/bin/tootctl emoji import ''${category} --overwrite ''${category_name_arg}
      done
    '';
    # mkforce is needed since environment.PATH is already defined for all systemd services.
    # However by simply using mastodon-webs entire environment, we already have imagemagic and other potential runtime dependencies already installed
    environment = lib.mkForce config.systemd.services.mastodon-web.environment;
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
    enable = true;
    package = pkgs.elasticsearch7;
    extraJavaOptions = [ "-Xms750m" "-Xmx750m" ];
  };

  systemd.services."mastodon-search-deploy" = {
    environment = lib.mkForce config.systemd.services.mastodon-web.environment;
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "elasticsearch.service" "postgresql.service" ];
    requires = [ "elasticsearch.service" "postgresql.service" ];
    script = ''
      ${mastoConfig.package}/bin/tootctl search deploy
    '';
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

      EnvironmentFile = "/var/lib/mastodon/.secrets_env";
    };
  };

  programs.msmtp = {
    enable      = true;
    setSendmail = false;
    accounts    = {
      default = {
        auth         = true;
        tls          = true;
        tls_starttls = false;
        host         = "telesto.host.static.dont-break.it";
        port         = 465;
        user         = "kuschelhaufen@cuties.social";
        from         = "${config.networking.fqdn} <kuschelhaufen@cuties.social>";
        passwordeval = "cat ${config.sops.secrets."kuschelhaufen-at-cuties-social".path}";
      };
    };
  };

  systemd.services."email-notify@" = {
    path = [ pkgs.util-linux ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.runtimeShell} -c "{ echo -n 'Message-ID: <$(uuidgen)@${config.networking.fqdn}>t\nSubject:[${config.networking.fqdn}] Service failed: %i\n\n' &  ${pkgs.systemd}/bin/systemctl status %i;} | ${pkgs.msmtp}/bin/msmtp -v cuties@cuties.social"
      '';
    };
  };

  systemd.services.redis-mastodon.serviceConfig = {
    UMask = lib.mkForce "0027"; # 0077 is default in the mastodon module
    StateDirectoryMode = lib.mkForce "0750"; # 0700 is default in the mastodon module
  };

  restic-backups.mastodon = {
    user = mastoConfig.user;
    passwordFile = config.sops.secrets."restic-repo-password".path;
    postgresDatabases = [ mastoConfig.database.name ];
    paths = [
      "/var/lib/mastodon/public-system/media_attachments" # Hardcoded in the NixOS module
      (config.services.redis.servers.mastodon.settings.dir + "/dump.rdb") # Mastodon advised: https://docs.joinmastodon.org/admin/backups/#redis
    ];
    targets = [{
      user = "cutiessocial";
      passwordFile = config.sops.secrets."restic-server-jules".path;
      hostname = "restic.jules.f2k1.de";
    }];
    timerSpec = "*-*-* 05:11:00";
  };

  systemd.services.restic-backup-mastodon.serviceConfig.SupplementaryGroups = config.systemd.services.redis-mastodon.serviceConfig.Group;
}
