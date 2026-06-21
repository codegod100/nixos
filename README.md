# NixOS Base: Niri + Noctalia v5 + Bun

This is a practical starting point for a new system.

Highlights:
- Bun from nixpkgs: `pkgs.bun`
- Niri compositor via NixOS module: `programs.niri.enable = true`
- Noctalia greeter via the NixOS flake input

Notes:
- v5 is currently treated as a flake workflow (`nix` flakes only).
- The v5 docs call out Wi‑Fi/Bluetooth/power profile/battery features needing:
  - `networking.networkmanager.enable`
  - `hardware.bluetooth.enable`
  - `services.upower.enable`
  - `services.power-profiles-daemon.enable` (or `services.tuned.enable`)

How to use:
1. You can keep `nixos` as host name, or change it in `flake.nix` if you want.
2. Run:
   - `nix --extra-experimental-features nix-command --extra-experimental-features flakes flake update`
   - `sudo nixos-rebuild switch --flake .#nixos`
