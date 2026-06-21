{
  description = "Prebuilt bun binary wrapped with steam-run";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bun-src = {
      url = "path:./bun-linux-x64";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, bun-src }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "bun-bin";
        version = "1.3.14";

        src = bun-src;

        nativeBuildInputs = with pkgs; [ makeWrapper ];

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin $out/libexec
          cp bun $out/libexec/bun
          chmod +x $out/libexec/bun

          makeWrapper ${pkgs.steam-run}/bin/steam-run $out/bin/bun \
            --add-flags "$out/libexec/bun"

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Prebuilt bun wrapped with steam-run for FHS compatibility";
          mainProgram = "bun";
          platforms = [ "x86_64-linux" ];
          license = licenses.mit;
        };
      };
    };
}
