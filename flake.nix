{
  description = "Starter NixOS base with Niri, Bun, and Noctalia v5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=67a99b5997cde7f64ad53d4f8f92c05ba7c22c67";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
    };

    zed-preview = {
      url = "path:./vendor/zed-preview";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bun-bin = {
      url = "path:./vendor/bun-bin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, determinate, home-manager, noctalia, noctalia-greeter, zen-browser, zed-preview, bun-bin, ... }@inputs:
    let
      system = "x86_64-linux";
      hostName = "nixos";
      username = "nandi";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username;
        };
        modules = [
          determinate.nixosModules.default
          noctalia-greeter.nixosModules.default
          ./system.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = { inherit inputs username; };
              users.${username} = import ./home.nix;
            };
          }
        ];
      };

      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs username; };
        modules = [
          ({ pkgs, ... }: {
            home-manager.backupFileExtension = "backup";
            home.packages = [
              zed-preview.packages.${system}.default
              bun-bin.packages.${system}.default
            ];
          })
          ./home.nix
        ];
      };
    };
}
