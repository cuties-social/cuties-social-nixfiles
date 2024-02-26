inputs: final: prev:
rec {
  mastodon = prev.mastodon.override {
    pname = "mastodon-cuties-socal";
    version = "4.2.7";
    gemset = builtins.toString (final.fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixpkgs/61acce0cb596050f5fa1c6ebf3f339a893361028/pkgs/servers/mastodon/gemset.nix";
      hash = "sha256-Npny6jwon/xdTMU7xOZSZmiwId5IMDUgno1dG1FGkhA=";
    });
    patches = [
      ./mastodon/account.patch
      ./mastodon/account_spec.patch
      ./mastodon/compose_form.patch
      ./mastodon/initial_state_serializer.patch
      ./mastodon/instance_serializer.patch
      ./mastodon/poll_form.patch
      ./mastodon/poll_validator.patch
      ./mastodon/show.patch
      ./mastodon/status_length_validator.patch
      ./mastodon/troet.patch
      (final.fetchpatch {
        url = "https://github.com/mastodon/mastodon/compare/v4.2.6...v4.2.7.patch";
        hash = "sha256-8FhlSIHOKIEjq62+rp8QdHY87qMCtDZwjyR0HabdHig=";
      })
    ];
  };

  customEmojis = prev.stdenv.mkDerivation {
    name = "custom-emojis-cuties-social";
    src = inputs.custom-emojis;

    buildInputs = with final.pkgs; [
      gnutar
      findutils
    ];

    buildPhase = ''
      patchShebangs build_tar_files.sh test.sh
      ./build_tar_files.sh
    '';

    installPhase = ''
      mkdir $out
      cp build/*.tar.gz $out/
    '';
  };
}
