inputs: final: prev:
rec {
  mastodon = prev.mastodon.override {
    pname = "mastodon-cuties-socal";
    patches = [
      ./mastodon/allpatches.patch
      ./mastodon/troet.patch
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
