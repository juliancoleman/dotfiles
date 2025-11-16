# Disable the fish greeting
set -U fish_greeting

# Configure new paths
set -gx PATH $HOME/.local/bin $PATH

# We know we will be using XDG_CONFIG_HOME, but MacOS may not
set -gx XDG_CONFIG_HOME $HOME/.config

# TODO: Load/unload mise upon entering/leaving a directory

# Set terminal colors appropriately

if test -z "$WAYLAND_DISPLAY" -a "$XDG_VTNR" -gt 0
	set -gx TERM vt100
else
	set -gx TERM xterm-256color
end

# Aliases
alias gg="lazygit"
alias t="tar -czf"
alias ls="eza" # we almost never want to use coreutils ls
alias cd="z" # we almost never want to use coreutils cd
