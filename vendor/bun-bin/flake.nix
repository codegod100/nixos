{
  description = "Prebuilt bun binary wrapped with steam-run";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "bun";
        version = "1.3.14";

        nativeBuildInputs = with pkgs; [ makeWrapper ];

        dontUnpack = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin $out/libexec
          local bun_src=${/home/nandi/.local/share/nixos-vendor/bun-linux-x64/bun}
          cp $bun_src $out/libexec/bun
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
