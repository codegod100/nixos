{
  description = "Zed Preview editor packaged from prebuilt binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zed-preview-src = {
      url = "path:./zed-preview.app";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, zed-preview-src }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "zed-preview";
        version = "0.1.0";

        src = zed-preview-src;

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

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin $out/libexec $out/lib $out/share

          # Install libexec binary (rename to avoid conflict with nixpkgs zed-editor)
          cp libexec/zed-editor $out/libexec/zed-preview

          # Install bundled libraries
          cp lib/* $out/lib/

          # Make zed-preview the main executable with wayland and bundled libs in LD_LIBRARY_PATH
          makeBinaryWrapper $out/libexec/zed-preview $out/bin/zed-preview \
            --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.wayland ]}:${placeholder "out"}/lib

          # Install desktop file
          mkdir -p $out/share/applications
          cp share/applications/dev.zed.Zed-Preview.desktop $out/share/applications/
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
