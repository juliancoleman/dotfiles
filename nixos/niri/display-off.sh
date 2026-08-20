#!/bin/sh
for out in $(wlopm --list 2>/dev/null | awk 'NR>1 {print $1}'); do
  wlopm --off "$out" 2>/dev/null || true
done
