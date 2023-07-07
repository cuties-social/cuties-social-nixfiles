{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs_release_branch.url = "github:NixOS/nixpkgs/release-23.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, nixpkgs_release_branch }: let
    overlays = [
      sops-nix.overlays.default
      (_: prev: { inherit (nixpkgs_release_branch.legacyPackages.${prev.system}) mastodon; })
      (import ./packages/default.nix)
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
