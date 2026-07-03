#!/usr/bin/env bash
# Memory usage tooltip with units
mem_total=$(free -h | awk '/^Mem:/ {print $2}')
mem_used=$(free -h | awk '/^Mem:/ {print $3}')
mem_free=$(free -h | awk '/^Mem:/ {print $7}')
swap_total=$(free -h | awk '/^Swap:/ {print $2}')
swap_used=$(free -h | awk '/^Swap:/ {print $3}')

tooltip="Used: ${mem_used} / ${mem_total}\nFree: ${mem_free}\nSwap: ${swap_used} / ${swap_total}"

# Check if memory usage >= 80%
mem_pct=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
class="normal"
[ "$mem_pct" -ge 80 ] && class="critical"

printf '{"text":"󰍛","tooltip":"%s","class":"%s"}' "$tooltip" "$class"
