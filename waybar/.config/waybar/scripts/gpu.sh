#!/usr/bin/env bash
# GPU status - multi-host
#   * Desktop (Nvidia): nvidia-smi -> utilisation, VRAM, temp, name
#   * Asahi (Apple Silicon): the asahi AGX driver (as of 6.17) exposes no
#     live utilisation/temperature/frequency to userspace (no hwmon, no
#     devfreq, no fdinfo engine stats). Emit class="hidden" so the CSS
#     rule (#custom-gpu.hidden) collapses the widget out of the bar.

tooltip=""
text_class="normal"

# --- Asahi: detect the asahi AGX driver via DRM uevent -------------------
AGX_UEVENT=""
for u in /sys/class/drm/card*/device/uevent; do
    [ -r "$u" ] || continue
    if grep -q "DRIVER=asahi" "$u" 2>/dev/null; then
        AGX_UEVENT="$u"
        break
    fi
done

if [ -n "$AGX_UEVENT" ]; then
    # No live GPU stats available on Asahi; hide the widget.
    printf '{"text":"","tooltip":"","class":"hidden"}'
    exit 0
fi

# --- Desktop: Nvidia via nvidia-smi --------------------------------------
gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "GPU")

tooltip="${gpu_name}\nUtilisation: ${gpu_util}%\nVRAM: ${gpu_mem_used}MB / ${gpu_mem_total}MB\nTemp: ${gpu_temp}C"
text_class=$([ "$gpu_util" -ge 99 ] && echo critical || echo normal)

printf '{"text":"󰢮","tooltip":"%s","class":"%s"}' "$tooltip" "$text_class"
