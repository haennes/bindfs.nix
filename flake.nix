{
  description = "bindmounts abstraction for nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    {
      nixpkgs,
      self,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
      pkgsForSystem = system: (import nixpkgs { inherit system; });
    in
    {
      nixosModules = rec {
        bindfs = import ./module.nix;
        default = bindfs;
      };
      nixosConfigurations.pcA = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./example/example.nix
          self.nixosModules.bindfs
        ];
      };
      formatter = forAllSystems (
        system:
        let
          pkgs = (pkgsForSystem system);
        in
        pkgs.nixfmt-rfc-style
      );
    };
}
