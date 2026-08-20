{ config, lib, pkgs, ... }:
{
  home.username = "julian";
  home.homeDirectory = "/home/julian";
  home.stateVersion = "25.11";
  # ── Shell ──────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];
    # Aliases (from config.fish.backup personal section)
    shellAliases = {
      gg = "lazygit";
      t = "tar -czf";
      ls = "eza";   # we almost never want to use coreutils ls
      cd = "z";     # we almost never want to use coreutils cd
    };
    # Runs for every shell (login + interactive + non-interactive)
    shellInit = ''
      # Disable the fish greeting
      set -g fish_greeting
      # Carapace completions
      set -gx CARAPACE_BRIDGES 'fish'
      carapace _carapace | source
      # Pay-respects
      pay-respects fish | source
    '';
    # Runs only for interactive shells
    interactiveShellInit = ''
      # Terminal colors — NixOS-specific
      if set -q IS_NIXOS
        if test -z "$WAYLAND_DISPLAY" -a -n "$XDG_VTNR" -a "$XDG_VTNR" -gt 0
          set -gx TERM vt100
        else
          set -gx TERM xterm-256color
        end
        # Niri is now launched by greetd, not fish
      end
    '';
    # Custom functions (from conf.d/ and functions/)
    functions = {
      # Override eza with --icons (from conf.d/eza.fish)
      eza = "command eza $argv --icons";
      # Custom lambda prompt (from functions/fish_prompt.fish)
      fish_prompt = ''
        set -l __last_command_exit_status $status
        if not set -q -g __fish_arrow_functions_defined
          set -g __fish_arrow_functions_defined
          function _git_branch_name
            set -l branch (git symbolic-ref --quiet HEAD 2>/dev/null)
            if set -q branch[1]
              echo (string replace -r '^refs/heads/' ''' $branch)
            else
              echo (git rev-parse --short HEAD 2>/dev/null)
            end
          end
          function _is_git_dirty
            not command git diff-index --cached --quiet HEAD -- &>/dev/null
            or not command git diff --no-ext-diff --quiet --exit-code &>/dev/null
          end
          function _is_git_repo
            type -q git
            or return 1
            git rev-parse --git-dir >/dev/null 2>&1
          end
          function _repo_branch_name
            _$argv[1]_branch_name
          end
          function _is_repo_dirty
            _is_$argv[1]_dirty
          end
          function _repo_type
            if _is_git_repo
              echo git
              return 0
            end
            return 1
          end
        end
        set -l cyan (set_color -o cyan)
        set -l yellow (set_color -o yellow)
        set -l red (set_color -o red)
        set -l green (set_color -o green)
        set -l blue (set_color -o blue)
        set -l norma (set_color normal)
        set -l arrow_color "$green"
        if test $__last_command_exit_status != 0
          set arrow_color "$red"
        end
        set -l lambda (printf "\u03bb")
        set -l arrow "$arrow_color\n$lambda "
        if fish_is_root_user
          set arrow_color "$red"
          set arrow "$arrow_color\n# "
        end
        set -l cwd $cyan (prompt_pwd | path basename)
        set -l repo_info
        if set -l repo_type (_repo_type)
          set -l repo_branch $red(_repo_branch_name $repo_type)
          set repo_info "$blue $repo_type:($repo_branch$blue)"
          if _is_repo_dirty $repo_type
            set -l dirty "$yellow x"
            set repo_info "$repo_info$dirty"
          end
        end
        echo -n -s -e $cwd $repo_info $normal $arrow
      '';
    };
  };
  # ── Completion / tool integrations (native home-manager) ──────
  programs.zoxide.enable = true;
  programs.carapace.enable = true;
  # ── Font rendering ─────────────────────────────────────────────
  fonts.fontconfig = {
    antialiasing = true;
    hinting = "full";
  };
  # ── Packages ───────────────────────────────────────────────────
  home.packages = with pkgs; [
    brave
    pkgs.catppuccin-cursors.latteLight
  ];
  # ── Session variables & paths ──────────────────────────────────
  home.sessionVariables = {
    IS_NIXOS = "1";
    XDG_CONFIG_HOME = "$HOME/.config";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
  # Hide terminal/system apps from app launchers by overriding their .desktop files
  xdg.dataFile = lib.mkMerge [
    (builtins.listToAttrs (map (name: {
      name = "applications/${name}.desktop";
      value.text = ''
        [Desktop Entry]
        Type=Application
        Name=${name}
        NoDisplay=true
      '';
    }) [
      "btop"
      "vim"
      "gvim"
      "nvim"
      "yazi"
      "nixos-manual"
      "nvidia-settings"
      "org.freedesktop.Xwayland"
      "xdg-desktop-portal-gnome"
      "xdg-desktop-portal-gtk"
    ]))
    # Proton Mail needs XWayland (native Wayland doesn't work)
    {
      "applications/proton-mail.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Proton Mail
        Exec=proton-mail --ozone-platform=x11 --no-sandbox %U
        Icon=proton-mail
        Categories=Network;Email;
      '';
    }
    # Steam's CEF UI must use XWayland; native Ozone Wayland can map a blank window.
    {
      "applications/steam.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Steam
        Exec=${pkgs.coreutils}/bin/env NIXOS_OZONE_WL=0 steam -cef-disable-gpu %U
        Icon=steam
        Categories=Game;
        Terminal=false
        MimeType=x-scheme-handler/steam;
      '';
    }

    # Official Signal AppImage — self-updating; avoids stale nixpkgs auth failures.
    {
      "applications/signal-desktop.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Signal
        Comment=Private messenger
        Exec=signal-desktop %U
        Icon=signal-desktop
        Categories=Network;InstantMessaging;
        Terminal=false
        StartupWMClass=Signal
      '';
    }
  ];

  # Bootstrap official Signal AppImage on first login; Signal updates it in-place.
  home.activation.installSignalAppImage = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu
    mkdir -p "$HOME/.local/opt/signal"
    APPIMAGE="$HOME/.local/opt/signal/signal-desktop.AppImage"
    if [ ! -f "$APPIMAGE" ]; then
      ${pkgs.curl}/bin/curl -fsSL -o "$APPIMAGE" https://updates.signal.org/desktop/signal-desktop.AppImage
      chmod +x "$APPIMAGE"
    fi
  '';

  home.file.".local/bin/signal-desktop" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec ${pkgs.appimage-run}/bin/appimage-run         "$HOME/.local/opt/signal/signal-desktop.AppImage"         --password-store=gnome-libsecret         "$@"
    '';
  };


  # Niri session scripts live in the git checkout at ~/dotfiles/nixos/niri/
  # (config.kdl spawn-sh paths). Do not home.file them here — that path is
  # the working tree, and HM would replace git files with store symlinks.
  # ── Niri compositor config ────────────────────────────────────
  xdg.configFile = {
    "niri/config.kdl".source = ../niri/config.kdl;
    "hypr/hyprlock.conf".source = ../niri/hyprlock.conf;
    "hypr/hypridle.conf".source = ../niri/hypridle.conf;
  };
}
