#!/bin/sh
# Lock screen on startup — frosted glass wallpaper, same as session lock
swaylock \
    --image /home/julian/dotfiles/nixos/niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg \
    --effect-blur 10x3 \
    --effect-vignette 0.5 \
    --ring-color 33ccff \
    --inside-color 00000050 \
    --font-size 14 \
    --indicator-radius 100 \
    --indicator-thickness 5
