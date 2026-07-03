#!/usr/bin/env bash
# GPU usage via nvidia-smi with tooltip
gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0)
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "GPU")

tooltip="${gpu_name}\nUtilization: ${gpu_util}%\nVRAM: ${gpu_mem_used}MB / ${gpu_mem_total}MB\nTemp: ${gpu_temp}C"

printf '{"text":"󰢮","tooltip":"%s","class":"%s"}' "$tooltip" "$([ "$gpu_util" -ge 99 ] && echo critical || echo normal)"
