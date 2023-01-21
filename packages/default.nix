final: prev:
rec {
  patchedMastodonSource = final.applyPatches {
    src = prev.fetchgit {
      url = "https://github.com/mastodon/mastodon.git";
      rev = "v${prev.mastodon.version}";
      sha256 = "1z0fgyvzz7nlbg2kaxsh53c4bq4y6n5f9r8lyfa7vzvz9nwrkqiq";
    };
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
