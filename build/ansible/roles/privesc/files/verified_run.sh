#!/bin/bash

if [[ $# -lt 1 || "$1" != "--exec="* ]]; then
    echo "Usage: $0 --exec=/path/to/script"
    exit 1
fi

EXEC_SCRIPT="${1#--exec=}"
CHECKSUM_DIR="/etc/verified_run/checksums"

verify_checksums() {
    local script_path="$1"
    local failed=0

    # Extract unique command names from the provided script
    local commands
    commands=$(awk '
    {
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^[a-zA-Z0-9_]+$/) {
                print $i
            }
        }
    }' "$script_path" | sort | uniq)

    for command in $commands; do
        local binary="/usr/bin/$command"
        if [[ -x "$binary" ]]; then
            local binary_checksum_file="$CHECKSUM_DIR/$command.txt"
            if [[ ! -f "$binary_checksum_file" ]]; then
                echo "Checksum file not found for $binary"
                failed=1
                continue
            fi

            # Verify the checksum of the binary against stored values
            local current_checksum
            current_checksum=$(crc32 "$binary")
            local stored_checksum
            stored_checksum=$(cat "$binary_checksum_file")

            if [[ "$current_checksum" != "$stored_checksum" ]]; then
                echo "Checksum mismatch for $binary"
                failed=1
            fi
        fi
    done

    return $failed
}

verify_checksums "$EXEC_SCRIPT"
if [[ $? -ne 0 ]]; then
    echo "Verification failed. Aborting execution of $EXEC_SCRIPT."
    exit 1
fi

# Execute the script after all checks pass
echo "Executing $EXEC_SCRIPT."
bash "$EXEC_SCRIPT"
