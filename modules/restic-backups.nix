{ options, config, pkgs, lib, ... }:

with lib;

let
  backups = config.restic-backups;

  backupOpts = { ... }: {
    options = {

      user = mkOption {
        type    = types.str;
        default = "root";
      };

      passwordFile = mkOption {
        type = types.str;
      };

      paths = mkOption {
        type    = with types; listOf str;
        default = [];
      };

      postgresDatabases = mkOption {
        type    = with types; listOf str;
        default = [];
      };

      targets = mkOption {
        type    = with types; listOf str;
        default = [ "jules.f2k1.de" ];
      };

      timerConfig = mkOption {
        type    = types.attrs;
        default = {
          OnCalendar         = "daily";
          RandomizedDelaySec = 300;
        };
      };

    };
  };

in {

  options.restic-backups = mkOption {
    type    = with types; attrsOf (submodule backupOpts);
    default = {};
  };

  config = mkIf (backups != {}) {

    systemd.services = mapAttrs' (
      name: backup: nameValuePair "restic-backup-${name}" {
        restartIfChanged = false;
        requires         = [ "network.target" "local-fs.target" ];
        onFailure        = [ "email-notify@%i.service" ];

        path = [
          pkgs.restic
        ] ++ optionals (backup.postgresDatabases != []) [
          config.services.postgresql.package
          pkgs.zstd
        ];

        serviceConfig    = {
          Type               = "oneshot";
          User               = backup.user;
          RuntimeDirectory   = "restic-backup-${name}";
          CacheDirectory     = "restic-backup-${name}";
          CacheDirectoryMode = "0700";
#          ReadWritePaths     = backup.paths;
          PrivateTmp         = true;
          ProtectHome        = true;
          ProtectSystem      = "strict";
          Environment        = "RESTIC_PASSWORD_FILE=/tmp/passwordFile";
          ExecStartPre = [
            (
              "!" + (pkgs.writeScript "privileged-pre-start" (''
                #!${pkgs.runtimeShell}
                set -eu pipefail

                cp ${backup.passwordFile} /tmp/passwordFile;
                chown ${backup.user} /tmp/passwordFile;
                ${if builtins.elem "jules.f2k1.de" backup.targets then ''
                  cp /run/secrets/restic-server-jules    /tmp/jules.f2k1.de;
                  chown ${backup.user} /tmp/jules.f2k1.de;
                '' else "" }

              ''))
            )
            (
              pkgs.writeScript "pre-start" (''
                #!${pkgs.runtimeShell}
                set -eu pipefail

                '' + concatMapStringsSep "\n" (db: ''
                echo "Dumping Postgres-database: ${db}"
                mkdir -p /tmp/postgresDatabases
                pg_dump ${db} | zstd --rsyncable > /tmp/postgresDatabases/${db}.sql.zst
                [ $(du -b /tmp/postgresDatabases/${db}.sql.zst | cut -f1) -gt "50" ] || exit 1
              '') backup.postgresDatabases)
            )
          ];
        };

        script = ''
          set -eu pipefail
          export XDG_CACHE_HOME=/var/cache/restic-backup-${name}

        '' + concatMapStringsSep "\n\n" (server: ''
          echo "Backing up to: ${server}"

          export RESTIC_REPOSITORY="rest:https://cutiessocial:$(cat /tmp/${server})@restic.${server}/${config.networking.hostName}-${name}"

          #create repo if it not exists
          restic snapshots || restic init

          #backup files
          restic backup ${escapeShellArgs (backup.paths ++ optional (backup.postgresDatabases != []) "/tmp/postgresDatabases") }

          restic check
        '') backup.targets;

      }
    ) backups;

    systemd.timers = mapAttrs' (
      name: backup: nameValuePair "restic-backup-${name}" {
        wantedBy    = [ "timers.target" ];
        timerConfig = backup.timerConfig;
      }
    ) backups;

  };

}
