#!/bin/bash
#
# This entrypoint script is responsible for validating the container's
# environment, setting sensible defaults, and launching the specified
# T7x (Black Ops 3) game server.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/game-config.sh"

# --- Step 1: Link Game Files ---
SOURCE_DIR="/home/plutainer/gamefiles"
DEST_DIR="/home/plutainer/app/gamefiles"
mkdir -p "$DEST_DIR"

echo "Linking files for t7x (Black Ops III)..."
ln -sf "$SOURCE_DIR"/{codlogo.bmp,machinecfg,steam_api64.dll,steamclient64.dll,tier0_s64.dll,vstdlib_s64.dll} "$DEST_DIR"/

# T7x expects BlackOps3.exe or BlackOps3_UnrankedDedicatedServer.exe in its directory
for exe in BlackOps3.exe BlackOps3_UnrankedDedicatedServer.exe; do
  if [[ -f "$SOURCE_DIR/$exe" ]]; then
    ln -sf "$SOURCE_DIR/$exe" "$DEST_DIR"/
  fi
done

# Create zone/ as a real directory with symlinked contents so configs can be
# placed alongside the read-only game data (same approach as T4's main/)
mkdir -p "$DEST_DIR/zone"
ln -sf "$SOURCE_DIR"/zone/* "$DEST_DIR"/zone/

# --- Step 2: Download/Update T7x ---
ALTER_EXE_LOC="$DEST_DIR/t7x.exe"
if [[ ! -f "${ALTER_EXE_LOC}" ]]; then
  echo "First container run detected. Downloading T7x... This may take a moment."
  wget -q -O "$ALTER_EXE_LOC" https://master.bo3.eu/t7x/t7x.exe
else
  if [[ "${ALTER_AUTO_UPDATE}" == "false" ]]; then
    echo "Skipping T7x update because ALTER_AUTO_UPDATE is set to 'false'."
  else
    echo "Checking for T7x updates..."
    wget -q -O "$ALTER_EXE_LOC" https://master.bo3.eu/t7x/t7x.exe
  fi
fi

cd "$DEST_DIR"

# --- Step 3: Validate Required Environment Variables ---
MISSING_VAR=false
INVALID_VAR=false
VALID_GAMES="t7x"
ALTER_SERVER_NAME=${ALTER_SERVER_NAME:-"T7x Docker Server"}

if [[ -z "${ALTER_GAME}" ]]; then
  echo "[ERROR] The 'ALTER_GAME' environment variable is not set." >&2
  MISSING_VAR=true
elif [[ ! " ${VALID_GAMES} " =~ " ${ALTER_GAME} " ]]; then
  echo "[ERROR] Invalid value for 'ALTER_GAME': \"${ALTER_GAME}\"." >&2
  INVALID_VAR=true
fi

if [[ -z "${ALTER_CONFIG_FILE}" ]]; then
  echo "[ERROR] The 'ALTER_CONFIG_FILE' environment variable is not set." >&2
  echo "  > You must specify the name of the server configuration file (e.g., 'server_zm.cfg')." >&2
  MISSING_VAR=true
fi

if [[ "$MISSING_VAR" == "true" || "$INVALID_VAR" == "true" ]]; then
  echo "-------------------------------------------------" >&2
  if [[ "$INVALID_VAR" == "true" ]]; then
      echo "An invalid value was provided. Valid game modes are: ${VALID_GAMES}" >&2
  fi
  echo "One or more configuration errors found. Halting startup." >&2
  echo "Exiting in 10 seconds..." >&2
  sleep 10
  exit 1
fi

# --- Step 4: Set Default Port (If Needed) ---
if [[ -z "${ALTER_PORT}" ]]; then
  echo "Optional ALTER_PORT is not set, determining default for ${ALTER_GAME}..."
  resolve_default_port "${ALTER_GAME}" || { sleep 10; exit 1; }
  ALTER_PORT="${DEFAULT_PORT}"
  echo "Default port set to ${ALTER_PORT}"
fi

# --- Step 5: Build Server Command Arguments ---
declare -a CMD_ARGS=(
    -dedicated
    -headless
    +set net_port "${ALTER_PORT}"
    +set logfile "2"
    +exec "${ALTER_CONFIG_FILE}"
)

if [[ -n "${ALTER_EXTRA_ARGS}" ]]; then
    CMD_ARGS+=(${ALTER_EXTRA_ARGS})
fi

# --- Step 6: Launch the T7x Server ---
# T7x requires a display even in dedicated/headless mode, so start a virtual
# framebuffer for Wine before launching
echo "Starting virtual display..."
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 320x240x24 &
sleep 1

echo "Starting T7x Server: ${ALTER_SERVER_NAME}"
echo "EXECUTING: wine t7x.exe ${CMD_ARGS[@]}"
exec wine t7x.exe "${CMD_ARGS[@]}"
