# NixOS Base: Niri + Noctalia v5 + Bun

This is a practical starting point for a new system.

Highlights:
- Bun from nixpkgs: `pkgs.bun`
- Niri compositor via NixOS module: `programs.niri.enable = true`
- Noctalia v5 via flake input `github:noctalia-dev/noctalia-shell/v5` (without
  `inputs.nixpkgs.follows`, per your request)
- Noctalia HM integration in `home.nix` using `programs.noctalia.systemd.enable`

Notes from Noctalia v5 docs:
- v5 is currently treated as a flake workflow (`nix` flakes only).
- The v5 docs call out Wi‑Fi/Bluetooth/power profile/battery features needing:
  - `networking.networkmanager.enable`
  - `hardware.bluetooth.enable`
  - `services.upower.enable`
  - `services.power-profiles-daemon.enable` (or `services.tuned.enable`)

How to use:
1. `username` is now inferred automatically from your shell context (`SUDO_USER`/`USER`), so no manual user replacement is needed.
2. You can keep `nixos` as host name, or change it in `flake.nix` if you want.
3. Run:
   - `nix --extra-experimental-features nix-command --extra-experimental-features flakes flake update`
   - `sudo nixos-rebuild switch --flake .#nixos`

If you hit issues:
- If `programs.noctalia.systemd.enable` is unstable for you, switch to spawning Noctalia from your niri config:
  add `spawn-at-startup "noctalia"` in `~/.config/niri/config.kdl`.
