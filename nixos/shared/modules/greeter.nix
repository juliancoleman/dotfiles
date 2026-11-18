# Login: greetd shows ReGreet's password prompt over the wallpaper. Nobody is logged in until the password
# is typed; PAM unlocks the keyring with it (modules/messaging.nix).
{ config, lib, pkgs, ... }:
let
  niri = lib.getExe config.programs.niri.package;
  regreet = lib.getExe config.services.displayManager.regreet.package;
  cursor = "catppuccin-latte-light-cursors";

  # The greeter's compositor is niri with nothing in it but ReGreet, full screen: the session's own
  # compositor, so the screens come up the way they will after login. When ReGreet exits niri quits,
  # which hands the seat back to greetd to start the session that was picked.
  greeterConfig = pkgs.writeText "greeter.kdl" ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
    }

    // The desktop's panel prefers 60Hz, as in the session's config.
    output "DP-2" {
        mode "2560x1440@165.000"
    }

    cursor {
        xcursor-theme "${cursor}"
        xcursor-size 24
    }

    hotkey-overlay {
        skip-at-startup
    }

    xwayland-satellite {
        off
    }

    prefer-no-csd

    layout {
        gaps 0
        focus-ring {
            off
        }
        border {
            off
        }
    }

    animations {
        off
    }

    window-rule {
        open-fullscreen true
    }

    // Nothing is bound: the greeter can't start or close anything.
    binds {
    }

    spawn-at-startup "${pkgs.runtimeShell}" "-c" "${regreet}; ${niri} msg action quit --skip-confirmation"
  '';
in
{
  services.greetd.settings.default_session.command =
    "${pkgs.dbus}/bin/dbus-run-session ${niri} -c ${greeterConfig}";

  services.displayManager.regreet = {
    enable = true;
    settings = {
      # Straight to the password for whoever logged in last; the user and session pickers show only the
      # first time.
      skip_selection = true;
      background = {
        path = "${../../niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg}";
        fit = "Cover";
      };
      GTK.application_prefer_dark_theme = true;
      widget.clock.format = "%A %-I:%M %p";
    };
    # The shell's surface and ink (qs Theme): one dark rounded card, no accent colors.
    extraCss = ''
      frame.background {
        border: none;
        border-radius: 22px;
        background-color: rgba(22, 24, 26, 0.92);
        color: #F7F3E9;
        padding: 6px;
      }

      button {
        border-radius: 10px;
      }

      button.suggested-action {
        background: #F7F3E9;
        color: #16181A;
      }

      button.destructive-action {
        background: rgba(22, 24, 26, 0.92);
        color: #F7F3E9;
      }
    '';
    font = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Sans";
      size = 14;
    };
    cursorTheme = {
      package = pkgs.catppuccin-cursors.latteLight;
      name = cursor;
    };
  };

  # ReGreet lists the sessions it finds here; niri-session is the only one.
  environment.pathsToLink = [ "/share/wayland-sessions" ];
}
