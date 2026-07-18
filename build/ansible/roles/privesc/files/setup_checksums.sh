#!/bin/bash
# Recompute and store CRC32 checksums of all /usr/bin binaries.
# Re-run after ANY update that changes /usr/bin/echo or /usr/bin/grep, otherwise
# verified_run.sh will report a mismatch and refuse to run monitor.sh.
CHECKSUM_DIR="/etc/verified_run/checksums"

if [[ ! -d "$CHECKSUM_DIR" ]]; then
    mkdir -p "$CHECKSUM_DIR"
fi

for bin in /usr/bin/*; do
    [ -f "$bin" ] || continue
    name="$(basename "$bin")"
    crc32 "$bin" > "$CHECKSUM_DIR/$name.txt" 2>/dev/null
done

echo "Checksums written to $CHECKSUM_DIR"
