#!/usr/bin/env bash
# Get hour, minute, and AM/PM in Japanese + calendar tooltip
ampm=$(date +%p)
if [[ "$ampm" == "AM" ]]; then
    jpampm="午前"
else
    jpampm="午後"
fi
hour=$(date +%I)
min=$(date +%M)
string="$jpampm $hour $min"
vertical=$(echo "$string" | sed "s/./&\\n/g" | sed "s/\\n$//")

# Calendar (plain text)
calendar=$(cal)

# Use perl for safe JSON encoding
export VERTICAL="$vertical"
echo "$calendar" | perl -MJSON::PP -e '
    my $cal = do { local $/; <STDIN> };
    chomp $cal;
    my $text = $ENV{VERTICAL};
    print encode_json({ text => $text, tooltip => $cal });
' 2>/dev/null || echo "{\"text\":\"$vertical\"}"
