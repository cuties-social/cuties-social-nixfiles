{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # PR containing the 4.2.10 update, pulling it that way because its a security update.
    # https://github.com/NixOS/nixpkgs/pull/324587
    nixpkgs-324587.url = "github:NixOS/nixpkgs/pull/324587/head";
    custom-emojis = {
      url = "github:cuties-social/custom-emojis";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, ... }@inputs: let
    overlays = [
      sops-nix.overlays.default
      (_: prev: { inherit (inputs.nixpkgs-324587.legacyPackages.${prev.system}) mastodon; })
      (import ./packages/default.nix inputs)
    ];
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      overlays = overlays;
    };
  in {
    nixosConfigurations.kuschelhaufen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs; };
      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        ({pkgs, ...}: {
          nixpkgs.overlays = overlays;
          nixpkgs.config.allowUnfree = true;
        })
      ];
    };

    legacyPackages.x86_64-linux = pkgs;
  };
}
