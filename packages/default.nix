inputs: final: prev:
rec {
  mastodon = prev.mastodon.override {
    pname = "mastodon-cuties-socal";
    version = "4.2.6";
    gemset = builtins.toString (final.fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixpkgs/5cd625ed59521004edd40e4547c4843413ff4fce/pkgs/servers/mastodon/gemset.nix";
      hash = "sha256-GqeL/z9LBrxV0nuiMFLIE6/Gg3jhydJxt7N2vr6iZAQ=";
    });
    patches = [
      ./mastodon/allpatches.patch
      ./mastodon/troet.patch
      (final.fetchpatch {
        url = "https://github.com/mastodon/mastodon/compare/v4.2.5...v4.2.6.patch";
        hash = "sha256-ElTQFC73dPTiorVOIRCjuGxV8YuXTqNVbaOvil5KP9k=";
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
