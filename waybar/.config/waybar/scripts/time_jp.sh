#!/run/current-system/sw/bin/bash

# Get hour, minute, and AM/PM in Japanese
ampm=$(date '+%p')
if [[ "$ampm" == "AM" ]]; then
    jpampm="午前"
else
    jpampm="午後"
fi
hour=$(date '+%I')  # 12-hour, zero-padded
min=$(date '+%M')   # zero-padded

# Output as a single string
string="$jpampm $hour $min"
vertical=$(echo "$string" | sed 's/./&\\n/g' | sed 's/\\n$//')
echo "{\"text\": \"$vertical\"}"
