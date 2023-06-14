final: prev:
rec {
  patchedMastodonSource = final.applyPatches {
    inherit (prev.mastodon.src) src;
    /* src = prev.fetchFromGitHub {
      owner = "mastodon";
      repo = "mastodon";
      rev = "v${prev.mastodon.version}";
      sha256 = "sha256-/lyniar3TaQiDTaSKhfI6AF80sjo57VCjTydjv3T6kA=";
    }; */
    patches = [
      ./mastodon/allpatches.patch
      ./mastodon/troet.patch
    ];
  };

  mastodon = prev.mastodon.override {
    pname = "mastodon-cuties-socal";
    srcOverride = patchedMastodonSource;
  };

  customEmojis = prev.stdenv.mkDerivation {
    name = "custom-emojis-cuties-social";
    src = prev.fetchFromGitHub {
      owner = "cuties-social";
      repo = "custom-emojis";
      rev = "ea8575bfed2c6f259d04f3761a8781dc1ce3387d";
      hash = "sha256-XROjTzXHCDb/U9SR4McTrbcUSqPGC1eGH9YeVJcRMa8=";
    };

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
