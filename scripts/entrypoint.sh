#!/bin/bash
#
# This entrypoint script is responsible for branding and delegating the
# server startup to the appropriate game-specific script.
#

# --- Branding ---
cat << "EOF"

 ____  _       _        _
|  _ \| |_   _| |_ __ _(_)_ __   ___ _ __
| |_) | | | | | __/ _` | | '_ \ / _ \ '__|
|  __/| | |_| | || (_| | | | | |  __/ |
|_|   |_|\__,_|\__\__,_|_|_| |_|\___|_|

EOF

echo
echo "Brought to you by Ayymoss"
echo

if [[ -n "${PLUTO_GAME}" ]]; then
  echo "Plutonium game type detected. Handing off to Plutonium entrypoint..."
  exec /home/plutainer/.plutainer/plutoentry.sh
# TODO: Re-enable once iw4x/launcher download issue is resolved upstream
elif [[ -n "${IW4X_GAME}" ]]; then
  echo "[ERROR] IW4x support is temporarily disabled due to an upstream launcher issue." >&2
  echo "  > See: https://github.com/iw4x/launcher/issues" >&2
  echo "Exiting in 10 seconds..." >&2
  sleep 10
  exit 1
else
  echo "-------------------------------------------------" >&2
  echo "[ERROR] No game type specified." >&2
  echo "  > Please set either the 'PLUTO_GAME' or 'IW4X_GAME' environment variable." >&2
  echo "Exiting in 10 seconds..." >&2
  sleep 10
  exit 1
fi
