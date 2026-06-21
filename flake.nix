{
  description = "Starter NixOS base with Niri and Noctalia v5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=67a99b5997cde7f64ad53d4f8f92c05ba7c22c67";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
    };
  };

  outputs = { nixpkgs, determinate, noctalia, noctalia-greeter, ... }@inputs:
    let
      system = "x86_64-linux";
      hostName = "nixos";
      username = "nandi";
    in
    {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          determinate.nixosModules.default
          noctalia.nixosModules.default
          noctalia-greeter.nixosModules.default
          ({ config, lib, pkgs, modulesPath, ... }:
            {
              imports = [
                (modulesPath + "/installer/scan/not-detected.nix")
              ];

              nix = {
                registry.nixpkgs.flake = inputs.nixpkgs;
                nixPath = [ "nixpkgs=flake:nixpkgs" ];
                settings = {
                  experimental-features = [ "nix-command" "flakes" ];
                  warn-dirty = false;
                  substituters = [
                    "https://cache.nixos.org/"
                    "https://noctalia.cachix.org"
                    "https://codegod100.cachix.org"
                  ];
                  trusted-users = [
                    "root"
                    username
                  ];
                  trusted-substituters = [
                    "https://cache.nixos.org/"
                    "https://noctalia.cachix.org"
                    "https://codegod100.cachix.org"
                  ];
                  trusted-public-keys = [
                    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
                    "codegod100.cachix.org-1:LZFL5VrR644WUjleS3bLbVeOdzlXqzKznQWvD5MVthA="
                  ];
                };
              };

              boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
              boot.initrd.kernelModules = [ ];
              boot.loader.grub = {
                enable = true;
                device = "/dev/sda";
                useOSProber = true;
              };
              boot.kernelPackages = pkgs.linuxPackages_latest;
              boot.kernelModules = [ "kvm-intel" "v4l2loopback" ];
              boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
              boot.extraModprobeConfig = ''
                options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
              '';

              fileSystems."/" = {
                device = "/dev/disk/by-uuid/becd00b8-e3dc-4153-bb71-2a0a84863dcb";
                fsType = "ext4";
              };
              swapDevices = [ ];
              nixpkgs.hostPlatform = lib.mkDefault system;
              hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

              time.timeZone = "America/Los_Angeles";
              networking.hostName = hostName;
              networking.networkmanager.enable = true;

              services.flatpak.enable = true;

              xdg.portal = {
                enable = true;
                extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
              };
              services.tailscale.enable = true;
              virtualisation.docker.enable = true;
              systemd.services.opencode = {
                description = "OpenCode server";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];
                path = [ pkgs.bun ];
                serviceConfig = {
                  Type = "simple";
                  User = username;
                  WorkingDirectory = "/home/${username}";
                  Environment = [ "PATH=/home/${username}/.cache/.bun/bin:/run/current-system/sw/bin" ];
                  ExecStart = "${pkgs.bash}/bin/bash -lc 'exec opencode serve'";
                  Restart = "on-failure";
                  RestartSec = 5;
                };
              };
              i18n.defaultLocale = "en_US.UTF-8";
              i18n.extraLocaleSettings = {
                LC_ADDRESS = "en_US.UTF-8";
                LC_IDENTIFICATION = "en_US.UTF-8";
                LC_MEASUREMENT = "en_US.UTF-8";
                LC_MONETARY = "en_US.UTF-8";
                LC_NAME = "en_US.UTF-8";
                LC_NUMERIC = "en_US.UTF-8";
                LC_PAPER = "en_US.UTF-8";
                LC_TELEPHONE = "en_US.UTF-8";
                LC_TIME = "en_US.UTF-8";
              };
              console.keyMap = "us";
              hardware.bluetooth.enable = true;

              users.groups.greeter = { };
              users.users.greeter = {
                isSystemUser = true;
                group = "greeter";
              };

              services.greetd = {
                enable = true;
                settings.default_session = {
                  user = "greeter";
                };
              };
              programs.noctalia-greeter = {
                enable = true;
                greeter-args = "--session niri";
              };
              services.printing.enable = true;
              services.pulseaudio.enable = false;
              services.pipewire = {
                enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                pulse.enable = true;
                wireplumber.extraConfig."10-usb-speaker-soft-mixer" = {
                  "monitor.alsa.rules" = [
                    {
                      matches = [
                        {
                          "node.name" = "alsa_output.usb-1908_1331_2010123456787899-01.analog-stereo";
                        }
                      ];
                      actions = {
                        update-props = {
                          "api.alsa.soft-mixer" = true;
                        };
                      };
                    }
                  ];
                };
              };

              programs.niri.enable = true;
              programs.noctalia.enable = true;
              programs.firefox.enable = true;
              security.rtkit.enable = true;
              services.upower.enable = true;
              services.power-profiles-daemon.enable = true;
              nixpkgs.config.allowUnfree = true;
              fonts.packages = with pkgs; [
                jetbrains-mono
                noto-fonts
                noto-fonts-cjk-sans
                noto-fonts-color-emoji
              ];
              fonts.fontconfig.defaultFonts = {
                sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
                serif = [ "Noto Serif" "Noto Serif CJK SC" ];
                monospace = [ "JetBrains Mono" "Noto Sans Mono" ];
                emoji = [ "Noto Color Emoji" ];
              };
              environment.extraInit = ''
                export PATH="$PATH:/home/${username}/.cache/.bun/bin"
              '';

              users.users.${username} = {
                isNormalUser = true;
                description = "User";
                extraGroups = [ "networkmanager" "wheel" "audio" "video" "docker" ];
                subUidRanges = [{ startUid = 100000; count = 65536; }];
                subGidRanges = [{ startGid = 100000; count = 65536; }];
                shell = pkgs.nushell;
                packages = with pkgs; [
                  bun
                ];
              };

              system.stateVersion = "26.05";
            })
        ];
      };
    };
}
