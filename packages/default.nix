inputs: final: prev:
rec {
  mastodon = prev.mastodon.override {
    pname = "mastodon-cuties-socal";
    version = "4.2.5";
    patches = [
      ./mastodon/allpatches.patch
      ./mastodon/troet.patch
      (final.fetchpatch {
        url = "https://github.com/mastodon/mastodon/compare/v4.2.4...v4.2.5.patch";
        hash = "sha256-CtzYV1i34s33lV/1jeNcr9p/x4Es1zRaf4l1sNWVKYk=";
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
