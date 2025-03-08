{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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
