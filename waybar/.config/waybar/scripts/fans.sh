#!/usr/bin/env bash
# Fan speeds - multi-host
#   * Asahi (Apple Silicon): macsmc_hwmon exposes fan{N}_input + fan{N}_label
#   * Desktop (B450 + Nvidia): NCT6797D hwmon + nvidia-smi GPU fan %
# Find hwmon paths dynamically; indices can change between boots.

tooltip=""

# --- Asahi: macsmc_hwmon -------------------------------------------------
MACSMC_HWMON=$(grep -l macsmc_hwmon /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1)
if [ -n "$MACSMC_HWMON" ]; then
    MACSMC_DIR=$(dirname "$MACSMC_HWMON")
    for f in "$MACSMC_DIR"/fan*_input; do
        [ -e "$f" ] || continue
        rpm=$(cat "$f" 2>/dev/null)
        [ -z "$rpm" ] && continue
        lbl=$(echo "$f" | sed 's/_input$/_label/')
        name=$(cat "$lbl" 2>/dev/null)
        [ -z "$name" ] && name=$(basename "$f" _input)
        # On Apple Silicon 0 RPM is a real reading (fans spin down at idle),
        # not a missing header — report the actual figure.
        if [ "$rpm" -eq 0 ]; then
            tooltip="${tooltip}${name}: 0 RPM (idle)\n"
        else
            tooltip="${tooltip}${name}: ${rpm} RPM\n"
        fi
    done
fi

# --- Desktop: NCT6797D Super-IO ------------------------------------------
NCT_HWMON=$(grep -l nct6797 /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1)
if [ -n "$NCT_HWMON" ]; then
    NCT_DIR=$(dirname "$NCT_HWMON")
    for i in 1 2 3 4 5 6; do
        rpm=$(cat "${NCT_DIR}/fan${i}_input" 2>/dev/null)
        [ -z "$rpm" ] && continue
        if [ "$rpm" -eq 0 ]; then
            tooltip="${tooltip}Fan ${i}: --\n"
        else
            tooltip="${tooltip}Fan ${i}: ${rpm} RPM\n"
        fi
    done
fi

# --- Desktop: Nvidia GPU fan % -------------------------------------------
gpu_fan=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null)
if [ -n "$gpu_fan" ]; then
    tooltip="${tooltip}GPU: ${gpu_fan}%\n"
fi

# Trim empty lines / trailing newline
tooltip=$(echo -e "$tooltip" | sed '/^$/d')

# Escape for JSON
tooltip_escaped=$(echo "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
printf '{"text":"󰈐","tooltip":"%s","class":"normal"}' "$tooltip_escaped"
