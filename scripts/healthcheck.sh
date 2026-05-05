#!/bin/bash
#
# This script checks the server's health by determining the correct game,
# port, and config, and then sending an RCON "status" command.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/game-config.sh"

# --- Step 1: Detect Game Type ---
echo "[INFO] Detecting server type..."
detect_game_type || exit 1
echo "       - ${GAME_TYPE} server detected (${GAME_NAME})."

# --- Step 2: Check if health checks are explicitly disabled ---
if [[ "${HEALTHCHECK_FLAG}" == "false" ]]; then
  echo "[INFO] Health check is disabled by environment variable."
  exit 0
fi

# --- Step 3: Validate that required variables are set ---
echo "[INFO] Validating required environment variables..."
if [[ -z "${GAME_NAME}" || -z "${CONFIG_FILE}" ]]; then
  echo "[ERROR] Required env vars are missing for the detected game type." >&2
  exit 1
fi
echo "       - Game='${GAME_NAME}'"
echo "       - Config File='${CONFIG_FILE}'"

# --- Step 4: Determine the correct port to check ---
echo "[INFO] Determining server port..."
HEALTHCHECK_PORT=${CUSTOM_PORT}
if [[ -z "${HEALTHCHECK_PORT}" ]]; then
  echo "       - Custom port is not set, determining default for game '${BASE_GAME}'..."
  resolve_default_port || exit 1
  HEALTHCHECK_PORT="${DEFAULT_PORT}"
  echo "       - Default port set to ${HEALTHCHECK_PORT}."
else
  echo "       - Using custom port: ${HEALTHCHECK_PORT}."
fi

# --- Step 5: Determine the game-specific config file path ---
echo "[INFO] Determining configuration file path..."
resolve_config_path || exit 1
echo "       - Expecting config file at: ${CONFIG_PATH}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "[ERROR] Config file not found at ${CONFIG_PATH}" >&2
  exit 1
fi

# --- Step 6: Extract RCON password from config ---
echo "[INFO] Extracting RCON password from config..."
extract_rcon_password || exit 1
echo "       - RCON password extracted successfully."

# --- Step 7: Query the server ---
echo "[INFO] Querying server at 127.0.0.1:${HEALTHCHECK_PORT}..."
RESPONSE=$(python3 -c "
import sys
import pyquake3

try:
    port = '${HEALTHCHECK_PORT}'
    password = '${RCON_PASSWORD}'
    server = pyquake3.PyQuake3(f'127.0.0.1:{port}', rcon_password=password)
    print(server.rcon('status'))
except Exception as e:
    print(f'RCON connection failed: {e}', file=sys.stderr)
    sys.exit(1)
")

# --- Step 8: Validate the server's response ---
echo "[INFO] Validating server response..."
if echo "${RESPONSE}" | grep -q "map:"; then
  echo "[OK] Health check passed: Server is responsive on port ${HEALTHCHECK_PORT}."
  exit 0
else
  echo "[ERROR] Server response did not contain 'map:'" >&2
  echo "[ERROR] Received: ${RESPONSE}" >&2
  exit 1
fi
