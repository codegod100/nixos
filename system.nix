{ config, pkgs, inputs, username, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Podman/Buildah/skopeo require a signature policy. Use the permissive
  # default that ships with containers/common on most distros.
  environment.etc."containers/policy.json".text = ''
    {
      "default": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
  '';

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=flake:nixpkgs" ];
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      # Make Noctalia and codegod100 caches available for this system config and trust them explicitly.
      substituters = [
        "https://cache.nixos.org/"
        "https://noctalia.cachix.org"
        "https://codegod100.cachix.org"
      ];
      trusted-users = [
        "root"
        "nandi"
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

  # Kept from your working system baseline
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
  '';
  time.timeZone = "America/Los_Angeles";
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  services.flatpak.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
  services.tailscale.enable = true;
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

  users.groups.greeter = {};
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

  # Niri + Noctalia + user tooling
  programs.niri.enable = true;
  programs.firefox.enable = true;
  security.rtkit.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  nixpkgs.config.allowUnfree = true;
  fonts.packages = with pkgs; [ jetbrains-mono ];
  environment.extraInit = ''
    export PATH="$PATH:/home/${username}/.cache/.bun/bin"
  '';

  users.users.${username} = {
    isNormalUser = true;
    description = "User";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
    shell = pkgs.nushell;
    packages = with pkgs; [
      # Keep a working baseline while adding custom tools above.
    ];
  };

  system.stateVersion = "26.05";
}
