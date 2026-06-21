{ config, lib, inputs, pkgs, username, ... }:
let
  localHostName = "nixos";
  noctaliaPluginSourceName = "codegod100";
  noctaliaPluginRepoUrl = "https://github.com/codegod100/noctalia-plugins.git";
  installObsLiveBackgroundRemovalLite = pkgs.writeShellScriptBin "install-obs-live-backgroundremoval-lite" ''
    set -eu

    repo_dir="$HOME/.cache/live-plugins-hub"
    manifest_dir="$repo_dir/flatpak/com.obsproject.Studio.Plugin.LiveBackgroundRemovalLite"
    manifest="$manifest_dir/com.obsproject.Studio.Plugin.LiveBackgroundRemovalLite.json"

    if [ -d "$repo_dir/.git" ]; then
      ${pkgs.git}/bin/git -C "$repo_dir" fetch --depth=1 origin main
      ${pkgs.git}/bin/git -C "$repo_dir" reset --hard origin/main
    else
      rm -rf "$repo_dir"
      ${pkgs.git}/bin/git clone --depth=1 https://github.com/kaito-tokyo/live-plugins-hub.git "$repo_dir"
    fi

    ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    ${pkgs.flatpak}/bin/flatpak install --user -y flathub com.obsproject.Studio

    obs_sdk="$(${pkgs.flatpak}/bin/flatpak info com.obsproject.Studio | ${pkgs.gnugrep}/bin/grep '^         Sdk:' | ${pkgs.gawk}/bin/awk '{print $2}')"
    if [ -z "$obs_sdk" ]; then
      echo "Could not determine OBS Flatpak SDK" >&2
      exit 1
    fi

    ${pkgs.flatpak}/bin/flatpak install --user -y flathub "$obs_sdk"

    ${pkgs.python3}/bin/python3 - "$manifest" "$obs_sdk" <<'PY'
import json, pathlib, sys

manifest_path = pathlib.Path(sys.argv[1])
sdk_ref = sys.argv[2]

parts = sdk_ref.split("/")
if len(parts) >= 3:
    sdk_id = parts[0]
    sdk_branch = parts[2]
    sdk_value = f"{sdk_id}//{sdk_branch}"
else:
    sdk_value = sdk_ref

data = json.loads(manifest_path.read_text())
data["sdk"] = sdk_value
manifest_path.write_text(json.dumps(data, indent=2) + "\n")
PY

    cd "$manifest_dir"
    PATH="${pkgs.appstream}/bin:$PATH" \
    ${pkgs.flatpak-builder}/bin/flatpak-builder \
      --user \
      --install \
      --disable-rofiles-fuse \
      --force-clean \
      build-dir \
      "$(basename "$manifest")"
  '';
  syncNoctaliaPluginSource = pkgs.writeShellScript "sync-noctalia-plugin-source" ''
    set -eu

    if ! command -v noctalia >/dev/null 2>&1; then
      exit 0
    fi

    if noctalia msg status >/dev/null 2>&1; then
      noctalia msg plugins source add ${lib.escapeShellArg noctaliaPluginSourceName} git ${lib.escapeShellArg noctaliaPluginRepoUrl} >/dev/null 2>&1 || true
    fi
  '';
  waitForNetworkManager = pkgs.writeShellScript "wait-for-networkmanager" ''
    set -eu

    for _ in $(seq 1 30); do
      if ${pkgs.systemd}/bin/busctl --system status org.freedesktop.NetworkManager >/dev/null 2>&1; then
        exit 0
      fi
      sleep 1
    done

    exit 0
  '';
  footNewWindowHere = pkgs.writeShellScriptBin "foot-new-window-here" ''
    set -eu

    focused="$(${pkgs.niri}/bin/niri msg -j focused-window 2>/dev/null || true)"
    app_id="$(printf '%s' "$focused" | ${pkgs.jq}/bin/jq -r '.app_id // empty' 2>/dev/null || true)"
    title="$(printf '%s' "$focused" | ${pkgs.jq}/bin/jq -r '.title // empty' 2>/dev/null || true)"

    if [ "$app_id" != "foot" ]; then
      exec ${pkgs.foot}/bin/foot
    fi

    case "$title" in
      *@*": "*)
        remote="''${title%%: *}"
        cwd="''${title#*: }"
        host="''${remote#*@}"

        case "$cwd" in
          /*|~|~/*) ;;
          *)
            exec ${pkgs.foot}/bin/foot
            ;;
        esac

        case "$cwd" in
          "~")
            cwd_local="${config.home.homeDirectory}"
            ;;
          "~/"*)
            cwd_local="${config.home.homeDirectory}/''${cwd#~/}"
            ;;
          *)
            cwd_local="$cwd"
            ;;
        esac

        if [ "$host" = "${localHostName}" ] || [ "$host" = "localhost" ]; then
          exec ${pkgs.foot}/bin/foot --working-directory "$cwd_local"
        fi

        case "$cwd" in
          "~")
            exec ${pkgs.foot}/bin/foot ${pkgs.et}/bin/et -e -c 'cd -- "$HOME" && exec bash -l' "$remote"
            ;;
          "~/"*)
            cwd_tail="$(${pkgs.python3}/bin/python3 -c 'import shlex, sys; print(shlex.quote(sys.argv[1]))' "''${cwd#~/}")"
            exec ${pkgs.foot}/bin/foot ${pkgs.et}/bin/et -e -c "cd -- \"\$HOME\"/$cwd_tail && exec bash -l" "$remote"
            ;;
          *)
            cwd_quoted="$(${pkgs.python3}/bin/python3 -c 'import shlex, sys; print(shlex.quote(sys.argv[1]))' "$cwd")"
            exec ${pkgs.foot}/bin/foot ${pkgs.et}/bin/et -e -c "cd -- $cwd_quoted && exec bash -l" "$remote"
            ;;
        esac
        ;;
      *)
        exec ${pkgs.foot}/bin/foot
        ;;
    esac
  '';
  ladybirdDockScript = ''
    #!/usr/bin/env bash
    set -eu

    flatpak_bin="''${FLATPAK_BIN:-${pkgs.flatpak}/bin/flatpak}"
    niri_bin="''${NIRI_BIN:-${pkgs.niri}/bin/niri}"
    app_id="org.ladybird.Ladybird"

    find_niri_socket() {
      if [ -n "''${NIRI_SOCKET:-}" ] && [ -S "''${NIRI_SOCKET:-}" ]; then
        printf '%s\n' "$NIRI_SOCKET"
        return 0
      fi

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        for candidate in "$runtime_dir"/niri."$WAYLAND_DISPLAY".*.sock; do
          [ -S "$candidate" ] || continue
          printf '%s\n' "$candidate"
          return 0
        done
      fi

      for candidate in "$runtime_dir"/niri.*.sock; do
        [ -S "$candidate" ] || continue
        printf '%s\n' "$candidate"
        return 0
      done

      return 1
    }

    launch() {
      exec "$flatpak_bin" run --branch=master --arch=x86_64 --command=Ladybird --file-forwarding "$app_id" "$@"
    }

    focus_existing_window() {
      [ -x "$niri_bin" ] || return 1
      niri_socket="$(find_niri_socket)" || return 1

      windows_json="$(NIRI_SOCKET="$niri_socket" "$niri_bin" msg -j windows 2>/dev/null)" || return 1
      [ -n "$windows_json" ] || return 1

      window_id="$(
        ${pkgs.python3}/bin/python3 -c '
import json
import sys

try:
    windows = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)

for window in windows:
    app_id = str(window.get("app_id") or "").lower()
    title = str(window.get("title") or "").lower()
    payload = json.dumps(window, sort_keys=True).lower()
    if (
        app_id == "org.ladybird.ladybird"
        or app_id == "ladybird"
        or "ladybird" in title
        or "ladybird" in payload
    ):
        print(window["id"])
        raise SystemExit(0)

raise SystemExit(1)
' "$windows_json"
      )" || return 1

      [ -n "$window_id" ] || return 1
      NIRI_SOCKET="$niri_socket" "$niri_bin" msg action focus-window --id "$window_id" >/dev/null 2>&1
    }

    args=()
    for arg in "$@"; do
      case "$arg" in
        @@|@@u|@@f)
          ;;
        *)
          args+=("$arg")
          ;;
      esac
    done

    if [ "''${#args[@]}" -eq 0 ]; then
      focus_existing_window && exit 0
      launch
    fi

    launch "''${args[@]}"
  '';
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
  home.sessionPath = [
    "/home/${username}/.local/bin"
    "/home/${username}/.cache/.bun/bin"
  ];
  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXPKGS_ALLOW_UNFREE = "1";
    NIXOS_OZONE_WL = "1";
  };

  xdg.configFile."uv/uv.toml".text = ''
    python-preference = "only-system"
  '';

  programs.nushell = {
    enable = true;
    extraConfig = ''
      $env.config = ($env.config | merge { show_banner: false })
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableIonIntegration = false;
    enableNushellIntegration = true;
    enableZshIntegration = false;
    settings = {
      directory.truncation_length = 100;
      directory.truncate_to_repo = false;
    };
  };

  xdg.configFile."foot/foot.ini" = {
    force = true;
    text = ''
      [main]
      include=~/.config/foot/themes/noctalia
      font=JetBrains Mono:size=12
      selection-target=both

      [key-bindings]
      spawn-terminal=none
    '';
  };

  home.file.".local/bin/ladybird-dock" = {
    text = ladybirdDockScript;
    executable = true;
    force = true;
  };

  home.file.".local/share/applications/org.ladybird.Ladybird.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Name=Ladybird
      GenericName=Web Browser
      Exec=${config.home.homeDirectory}/.local/bin/ladybird-dock @@u %U @@
      Icon=org.ladybird.Ladybird
      DBusActivatable=false
      Type=Application
      Categories=Network;WebBrowser;
      Keywords=Qt;KDE;
      StartupNotify=false
      MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
      Actions=new-window;
      X-Purism-FormFactor=Workstation;
      X-Flatpak=org.ladybird.Ladybird

      [Desktop Action new-window]
      Name=New Window
      Exec=${pkgs.flatpak}/bin/flatpak run --branch=master --arch=x86_64 --command=Ladybird org.ladybird.Ladybird --new-window
    '';
  };

  home.file.".local/share/applications/nemo.desktop".text = ''
    [Desktop Entry]
    Name=Files
    Comment=Access and organize files
    Exec=nemo %U
    Icon=folder
    Terminal=false
    Type=Application
    StartupNotify=false
    Categories=GNOME;GTK;Utility;Core;
    MimeType=inode/directory;application/x-gnome-saved-search;
    Keywords=folders;filesystem;explorer;
  '';

  home.packages = [
    pkgs.adwaita-icon-theme
    pkgs.bazaar
    pkgs.btop
    pkgs.bubblewrap
    pkgs.chromium
    pkgs.devenv
    pkgs.kdePackages.dolphin
    pkgs.duf
    pkgs.easyeffects
    pkgs.emote
    pkgs.eternal-terminal
    pkgs.file
    pkgs.fish
    pkgs.flatpak-builder
    pkgs.foot
    pkgs.gh
    pkgs.git
    pkgs.htop
    pkgs.jetbrains-mono
    pkgs.jujutsu
    pkgs.nethogs
    pkgs.nh
    pkgs.nix-output-monitor
    pkgs.nodejs
    pkgs.papers
    pkgs.python312
    pkgs.ripgrep
    pkgs.tailscale
    pkgs.uv
    pkgs.valent
    pkgs.vim
    pkgs.wl-clipboard
    pkgs.xwayland-satellite
    pkgs.zed-editor
    inputs.zed-preview.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.bun-bin.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    footNewWindowHere
    installObsLiveBackgroundRemovalLite
  ];

  imports = [ inputs.noctalia.homeModules.default ];

  home.activation.niriUseFoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_file="${config.home.homeDirectory}/.config/niri/config.kdl"

    if [ -f "$config_file" ]; then
      sed -i \
        -e 's/Open a Terminal: alacritty/Open a Terminal: foot/g' \
        -e 's/spawn "alacritty"/spawn "foot"/g' \
        -e 's/Print { screenshot; }/Mod+Shift+S { screenshot; }/g' \
        -e '/Mod+Space hotkey-overlay-title="Open Launcher: Noctalia" { spawn-sh "noctalia msg panel-toggle launcher"; }/d' \
        -e '/Control+Shift+N hotkey-overlay-title="Open Terminal Here"/d' \
        -e '/spawn "foot-new-window-here"/d' \
        -e '/Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }/a\    Mod+Space hotkey-overlay-title="Open Launcher: Noctalia" { spawn-sh "noctalia msg panel-toggle launcher"; }\
    Control+Shift+N hotkey-overlay-title="Open Terminal Here" { spawn "'"${footNewWindowHere}/bin/foot-new-window-here"'"; }' \
        -e '/Mod+Period { expel-window-from-column; }/c\    Mod+Period hotkey-overlay-title="Emoji Picker: emote" { spawn "emote"; }\
    Mod+Shift+Period { expel-window-from-column; }' \
        "$config_file"
    fi
  '';

  home.activation.noctaliaReloadAfterSwitch = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v noctalia >/dev/null 2>&1; then
      if noctalia msg status >/dev/null 2>&1; then
        ${syncNoctaliaPluginSource}
        noctalia msg config-reload >/dev/null 2>&1 || true
      fi
    fi
  '';

  home.activation.setDolphinAsDefaultFileManager = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mimeapps="${config.home.homeDirectory}/.config/mimeapps.list"
    mkdir -p "$(dirname "$mimeapps")"
    touch "$mimeapps"

    ${pkgs.python3}/bin/python3 - "$mimeapps" <<'PY'
import configparser
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
config = configparser.ConfigParser(interpolation=None, strict=False)
config.optionxform = str
config.read(path)

if "Default Applications" not in config:
    config["Default Applications"] = {}

defaults = config["Default Applications"]
defaults["inode/directory"] = "org.kde.dolphin.desktop"
defaults["application/x-gnome-saved-search"] = "org.kde.dolphin.desktop"
defaults["x-scheme-handler/file"] = "org.kde.dolphin.desktop"

with path.open("w") as f:
    config.write(f, space_around_delimiters=False)
PY
  '';

  systemd.user.services.noctaliaPluginSourceSync = {
    Unit = {
      Description = "Register custom Noctalia plugin source";
      PartOf = [ config.wayland.systemd.target ];
      After = [
        config.wayland.systemd.target
        "noctalia.service"
      ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = syncNoctaliaPluginSource;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };

  # Start Noctalia from your user session using the Noctalia HM module.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    settings = {
      control_center.shortcuts = [
        { type = "wifi"; }
        { type = "bluetooth"; }
        { type = "caffeine"; }
        { type = "nightlight"; }
        { type = "notification"; }
        { type = "codegod100/focus-toggle:focus-toggle"; }
      ];

      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
    };
  };

  systemd.user.services.noctalia.Service.ExecStartPre = [
    waitForNetworkManager
  ];

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
      esac
    '';
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 3600;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
      }
    ];
  };
}
