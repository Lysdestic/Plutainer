#!/bin/bash
#
# Shared game configuration library.
# Sourced by entrypoint scripts, healthcheck, and rcon-cli to avoid
# duplicating port defaults, config path resolution, and game detection.
#

# Detect the game type from environment variables and set unified variables:
#   GAME_TYPE, GAME_NAME, BASE_GAME, CONFIG_FILE, CUSTOM_PORT, HEALTHCHECK_FLAG
detect_game_type() {
  if [[ -n "${PLUTO_GAME}" ]]; then
    GAME_TYPE="plutonium"
    GAME_NAME="${PLUTO_GAME}"
    BASE_GAME="${PLUTO_GAME%??}"
    CONFIG_FILE="${PLUTO_CONFIG_FILE}"
    CUSTOM_PORT="${PLUTO_PORT}"
    HEALTHCHECK_FLAG="${PLUTO_HEALTHCHECK}"
  elif [[ -n "${IW4X_GAME}" ]]; then
    GAME_TYPE="iw4x"
    GAME_NAME="${IW4X_GAME}"
    BASE_GAME="iw4x"
    CONFIG_FILE="${IW4X_CONFIG_FILE}"
    CUSTOM_PORT="${IW4X_PORT}"
    HEALTHCHECK_FLAG="${IW4X_HEALTHCHECK}"
  else
    echo "[ERROR] No game type detected. Set PLUTO_GAME or IW4X_GAME." >&2
    return 1
  fi
}

# Resolve the default port for a given BASE_GAME.
# Sets DEFAULT_PORT. Returns 1 if the game is unknown.
resolve_default_port() {
  local base_game="${1:-$BASE_GAME}"
  case "${base_game}" in
    "iw4x")      DEFAULT_PORT="28960" ;;
    "iw5")       DEFAULT_PORT="27016" ;;
    "t4" | "t5") DEFAULT_PORT="28960" ;;
    "t6")        DEFAULT_PORT="4976"  ;;
    *)
      echo "[ERROR] Could not determine default port for game '${base_game}'." >&2
      return 1
      ;;
  esac
}

# Resolve the config file path for the current game.
# Sets CONFIG_PATH. Requires GAME_TYPE, BASE_GAME, and CONFIG_FILE to be set.
resolve_config_path() {
  case "${GAME_TYPE}" in
    "plutonium")
      case "${BASE_GAME}" in
        "t4")  CONFIG_PATH="/home/plutainer/app/gamefiles/main/${CONFIG_FILE}" ;;
        "iw5") CONFIG_PATH="/home/plutainer/app/gamefiles/admin/${CONFIG_FILE}" ;;
        *)     CONFIG_PATH="/home/plutainer/app/plutonium/storage/${BASE_GAME}/${CONFIG_FILE}" ;;
      esac
      ;;
    "iw4x")
      CONFIG_PATH="/home/plutainer/app/gamefiles/userraw/${CONFIG_FILE}"
      ;;
    *)
      echo "[ERROR] Unknown game type '${GAME_TYPE}'." >&2
      return 1
      ;;
  esac
}

# Extract the RCON password from a config file.
# Sets RCON_PASSWORD. Requires CONFIG_PATH to be set.
extract_rcon_password() {
  if [[ ! -f "${CONFIG_PATH}" ]]; then
    echo "[ERROR] Config file not found at ${CONFIG_PATH}" >&2
    return 1
  fi
  RCON_PASSWORD=$(grep -v '^[[:space:]]*//' "${CONFIG_PATH}" | grep -i 'rcon_password' | sed -n 's/.*"\([^"]*\)".*/\1/p' | tail -1)
  if [[ -z "${RCON_PASSWORD}" ]]; then
    echo "[ERROR] Could not find 'rcon_password' in ${CONFIG_PATH}" >&2
    return 1
  fi
}
