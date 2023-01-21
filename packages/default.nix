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
      ./mastodon/0001-Apply-previous-custies-social-ansible-patches.patch
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
      rev = "576e7da7c7f3dff6876caab6ad49403b516d1b00";
      sha256 = "3xdiqpuwb6vvDY1x8mkYcXOwyiVnWfRRdhh6Zb3GP4E=";
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
