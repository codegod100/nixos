{
  description = "Zed Preview editor packaged from prebuilt binary";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "zed-preview";
        version = "0.1.0";

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeBinaryWrapper
        ];

        buildInputs = with pkgs; [
          alsa-lib
          glib
          libxcb
          libxkbcommon
          stdenv.cc.cc.lib
          libX11
          wayland
        ];

        dontUnpack = true;

        installPhase = ''
          runHook preInstall

          local src=${/home/nandi/.local/share/nixos-vendor/zed-preview.app}

          mkdir -p $out/bin $out/libexec $out/lib $out/share

          # Install libexec binary (rename to avoid conflict with nixpkgs zed-editor)
          cp $src/libexec/zed-editor $out/libexec/zed-preview

          # Install bundled libraries
          cp $src/lib/* $out/lib/

          # Make zed-preview the main executable with wayland and bundled libs in LD_LIBRARY_PATH
          makeBinaryWrapper $out/libexec/zed-preview $out/bin/zed-preview \
            --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.wayland ]}:${placeholder "out"}/lib

          # Install desktop file
          mkdir -p $out/share/applications
          cp $src/share/applications/dev.zed.Zed-Preview.desktop $out/share/applications/
          sed -i \
            -e 's/^TryExec=zed$/TryExec=zed-preview/' \
            -e 's/^Exec=zed /Exec=zed-preview /' \
            $out/share/applications/dev.zed.Zed-Preview.desktop

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Zed Preview - high-performance multiplayer code editor";
          mainProgram = "zed-preview";
          platforms = [ "x86_64-linux" ];
          license = licenses.unfree;
        };
      };
    };
}
