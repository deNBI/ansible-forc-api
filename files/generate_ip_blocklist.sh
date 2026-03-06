#!/bin/bash



# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Paths relative to script directory
INPUT="$SCRIPT_DIR/ip_blocklists.txt"
OUTPUT="/etc/openresty/nginx/block_ips_geo.conf"
TEMP="$SCRIPT_DIR/block_tmp.txt"

rm -f "$TEMP" "$OUTPUT"
# Check that list exists
if [[ ! -f $INPUT ]]; then
    echo "ERROR: $INPUT does not exist!"
    exit 1
fi

# Download all blocklists
while IFS= read -r url; do
    
    # Skip empty or commented lines in ip_blocklists.txt
    [[ -z "$url" ]] && continue
    [[ "$url" =~ ^# ]] && continue

    echo "Downloading: $url"

    # Append raw data to temp file
    curl -fsSL "$url" >> "$TEMP" || echo "Failed: $url"

done < "$INPUT"

# Check if anything was downloaded
if [[ ! -s "$TEMP" ]]; then
    echo "ERROR: download failed — TEMP file is empty!"
    exit 1
fi

echo "Cleaning downloaded data…"

# Remove comment lines only
# Keep everything else (IP, CIDR, netset formats)
grep -vE '^\s*#|^\s*;' "$TEMP" | sed '/^\s*$/d' > "$OUTPUT"

# Sort + dedupe
sort -u "$OUTPUT" -o "$OUTPUT"

rm "$TEMP"
echo "✔ Done"
echo "Final list: $OUTPUT"
wc -l "$OUTPUT"
