{ config, pkgs, ... }:
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
  ];
  # ── Session variables & paths ──────────────────────────────────
  home.sessionVariables = {
    IS_NIXOS = "1";
    XDG_CONFIG_HOME = "$HOME/.config";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
  # Hide terminal/system apps from wofi by overriding their .desktop files
  xdg.dataFile."applications/btop.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=btop
    NoDisplay=true
  '';
  xdg.dataFile."applications/vim.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=vim
    NoDisplay=true
  '';
  xdg.dataFile."applications/gvim.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=gvim
    NoDisplay=true
  '';
  xdg.dataFile."applications/nvim.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nvim
    NoDisplay=true
  '';
  xdg.dataFile."applications/yazi.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=yazi
    NoDisplay=true
  '';
  xdg.dataFile."applications/nixos-manual.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nixos-manual
    NoDisplay=true
  '';
  xdg.dataFile."applications/nvidia-settings.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nvidia-settings
    NoDisplay=true
  '';
  xdg.dataFile."applications/org.freedesktop.Xwayland.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=org.freedesktop.Xwayland
    NoDisplay=true
  '';
  xdg.dataFile."applications/xdg-desktop-portal-gnome.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=xdg-desktop-portal-gnome
    NoDisplay=true
  '';
  xdg.dataFile."applications/xdg-desktop-portal-gtk.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=xdg-desktop-portal-gtk
    NoDisplay=true
  '';
  # Proton Mail needs XWayland (native Wayland doesn't work)
  xdg.dataFile."applications/proton-mail.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton Mail
    Exec=proton-mail --ozone-platform=x11 --no-sandbox %U
    Icon=proton-mail
    Categories=Network;Email;
  '';
  # ── Niri compositor config ────────────────────────────────────
  # Hide terminal/system apps from app launcher (wofi)
  xdg.configFile."niri/config.kdl".source = ../niri/config.kdl;
  xdg.configFile."hypr/hyprlock.conf".source = ../niri/hyprlock.conf;
  xdg.configFile."wofi/config".source = ../wofi/config;
  xdg.configFile."wofi/style.css".source = ../wofi/style.css;
  xdg.configFile."mako/config".source = ../mako/config;
  xdg.configFile."waybar/config.jsonc".source = ../waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ../waybar/style.css;
  xdg.configFile."waybar/calendar.css".source = ../waybar/calendar.css;
  xdg.configFile."waybar/custom_modules/power_menu.xml".source = ../waybar/custom_modules/power_menu.xml;
  xdg.configFile."waybar/scripts/bluetooth_picker.sh".source = ../waybar/scripts/bluetooth_picker.sh;
  xdg.configFile."waybar/scripts/bluetooth_toggle.sh".source = ../waybar/scripts/bluetooth_toggle.sh;
  xdg.configFile."waybar/scripts/calendar.sh".source = ../waybar/scripts/calendar.sh;
  xdg.configFile."waybar/scripts/cpu.sh".source = ../waybar/scripts/cpu.sh;
  xdg.configFile."waybar/scripts/disk.sh".source = ../waybar/scripts/disk.sh;
  xdg.configFile."waybar/scripts/fans.sh".source = ../waybar/scripts/fans.sh;
  xdg.configFile."waybar/scripts/gpu.sh".source = ../waybar/scripts/gpu.sh;
  xdg.configFile."waybar/scripts/mem.sh".source = ../waybar/scripts/mem.sh;
  xdg.configFile."waybar/scripts/sleep.sh".source = ../waybar/scripts/sleep.sh;
  xdg.configFile."waybar/scripts/time_jp.sh".source = ../waybar/scripts/time_jp.sh;
  xdg.configFile."waybar/scripts/battery.sh".source = ../waybar/scripts/battery.sh;
}
