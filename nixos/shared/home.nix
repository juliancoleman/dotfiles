{ config, lib, pkgs, inputs, ... }:
let
  wallpaper = ../niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
  # The session's helper scripts, on PATH under the names niri/config.kdl binds.
  script = name: pkgs.writeScriptBin "niri-${name}" (builtins.readFile (../niri + "/${name}.sh"));
  lock = script "lock";
in
{
  home.username = "julian";
  home.homeDirectory = "/home/julian";
  home.stateVersion = "25.11";
  imports = [
    inputs.omp.homeManagerModules.default
    inputs.qs.homeManagerModules.default
  ];
  # -- OMP --------------------------------------------------------
  programs.omp = {
    enable = true;
    settings.startup.quiet = true;
  };
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
    interactiveShellInit = ''
      # Disable the fish greeting
      set -g fish_greeting
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
        set -l normal (set_color normal)
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
  programs.pay-respects.enable = true;
  # ── Font rendering ─────────────────────────────────────────────
  fonts.fontconfig = {
    antialiasing = true;
    hinting = "full";
  };
  # ── Packages ───────────────────────────────────────────────────
  home.packages = with pkgs; [
    brave
    catppuccin-cursors.latteLight
    lock
    (script "open-usb")
    (script "screenshot")
    (script "screenshot-region")
    (script "record-toggle")
  ];
  # ── Session variables & paths ──────────────────────────────────
  home.sessionVariables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    # Carapace also offers what fish's own completions know.
    CARAPACE_BRIDGES = "fish";
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
  ];

  # ── Niri compositor config ────────────────────────────────────
  xdg.configFile = {
    "niri/config.kdl".source = ../niri/config.kdl;
    "hypr/hyprlock.conf".text =
      builtins.replaceStrings [ "@wallpaper@" ] [ "${wallpaper}" ] (builtins.readFile ../niri/hyprlock.conf);
  };

  # ── Shell ─────────────────────────────────────────────────────
  # Quickshell bar and wallpaper. hypridle runs as a user service; the shell's Display settings pick when
  # the screen locks and turns off.
  programs.qs = {
    enable = true;
    inherit wallpaper;
    idle = {
      enable = true;
      lockCommand = "${lock}/bin/niri-lock";
    };
  };
}
