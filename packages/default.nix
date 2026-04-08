inputs: final: prev:
rec {
  mastodon = prev.mastodon.override {
    pname = "mastodon-cuties-socal";
    patches = [
      ./mastodon/account_field_limits.patch
      ./mastodon/status_max_characters.patch
      ./mastodon/troet.patch
      # ./mastodon/signup_message.patch
      ./mastodon/throttle_media_proxy.patch
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
