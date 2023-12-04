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
      rev = "main";
      hash = "sha256-nicCkl0VWCoSM98JDhEZUnN9VTrhUfrkngk6mXJdxpk=";
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
