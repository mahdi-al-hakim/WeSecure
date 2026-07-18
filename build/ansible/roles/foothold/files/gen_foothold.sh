#!/usr/bin/env bash
# Generates john's SSH keypair, installs the public key as john's authorized_keys,
# and scatters the PRIVATE key across /var/log/.activity.trace as 3 base64 fragments
# (the intended lateral-movement artifact). Idempotent-ish: guarded by `creates`.
set -euo pipefail
PASSPHRASE="${PASSPHRASE:?set PASSPHRASE}"
KEYCMT="${KEYCMT:-john@wesecure.com}"
LOG="${LOGPATH:-/var/log/.activity.trace}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. john's keypair (passphrase must be crackable per the writeup, e.g. in rockyou)
ssh-keygen -t rsa -b 4096 -N "$PASSPHRASE" -C "$KEYCMT" -f "$TMP/id_rsa" >/dev/null

# 2. install the public key for john
install -d -m 700 -o john -g john /home/john/.ssh
install -m 600 -o john -g john "$TMP/id_rsa.pub" /home/john/.ssh/authorized_keys

# 3. split the private-key file into 3 chunks, base64 each
python3 - "$TMP/id_rsa" "$TMP/frags" <<'PY'
import sys, base64, math
data = open(sys.argv[1], "rb").read()
n = 3
size = math.ceil(len(data) / n)
parts = [data[i*size:(i+1)*size] for i in range(n)]
with open(sys.argv[2], "w") as out:
    for p in parts:
        if p:
            out.write(base64.b64encode(p).decode() + "\n")
PY

# 4. write the log: debug.sh wrapper lines around the 3 B64-FRAG entries + noise
{
  echo "Jan 17 00:00:01 wesecure systemd[1]: Started debug trace collector."
  echo "Jan 17 00:00:05 wesecure debug.sh[1101]: Debug: verifying monitored binaries via /opt/sysutils/verified_run.sh"
  echo "Jan 17 00:00:12 wesecure debug.sh[1120]: Debug: checksum store /etc/verified_run/checksums consistent"
  min=0; pid=1154
  while IFS= read -r frag; do
    printf 'Jan 17 00:%02d:33 wesecure debug.sh[%d]: Debug: B64-FRAG => %s\n' "$min" "$pid" "$frag"
    min=$((min + 1)); pid=$((pid + 30))
  done < "$TMP/frags"
  echo "Jan 17 00:02:10 wesecure debug.sh[1250]: Debug: trace window closed"
} > "$LOG"
chown root:root_2fa "$LOG"
chmod 644 "$LOG"     # world-readable: mmcarTney+0 can read it
echo "foothold provisioned"
