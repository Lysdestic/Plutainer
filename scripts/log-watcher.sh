#!/bin/bash
#
# Maintains stable symlinks at /home/plutainer/app/logs/<name> pointing at the
# game log currently being written. Game logs move around per game/mod (e.g.
# plutonium/storage/t5/mods/<mod>/logs/games_zm.log), which makes IW4MAdmin
# configuration brittle. This watcher surfaces them in one predictable dir.
#
# Strategy:
#   - Record container boot time.
#   - Poll app/ for files matching known log names.
#   - The active log is the one with mtime >= boot time (stale logs from prior
#     sessions keep their old mtime and are ignored). Ties broken by newest.
#   - Update symlink only when target changes (idempotent).
#   - Create empty stub files at startup so host-side IW4MAdmin never sees a
#     dangling symlink during the window before the first write event.
#

APP_DIR=/home/plutainer/app
STABLE_DIR="$APP_DIR/logs"
POLL_INTERVAL="${PLUTAINER_LOG_POLL_INTERVAL:-2}"
LOG_NAMES=(games_mp.log games_zm.log console_mp.log console_zm.log)

if [[ "${PLUTAINER_LOG_SYMLINKS}" == "false" ]]; then
  echo "[log-watcher] disabled via PLUTAINER_LOG_SYMLINKS=false"
  exit 0
fi

mkdir -p "$STABLE_DIR"

for name in "${LOG_NAMES[@]}"; do
  target="$STABLE_DIR/$name"
  if [[ -L "$target" ]]; then
    # Leave existing symlinks from prior run in place until a fresh target is
    # identified. Preserves continuity for IW4MAdmin across container restarts
    # where the old log path is still valid.
    :
  elif [[ ! -e "$target" ]]; then
    touch "$target"
  fi
done

BOOT_TS=$(date +%s)

declare -A CURRENT_TARGET

echo "[log-watcher] started; boot_ts=$BOOT_TS stable_dir=$STABLE_DIR"

while true; do
  for name in "${LOG_NAMES[@]}"; do
    newest_path=""
    newest_mtime=0

    while IFS= read -r -d '' path; do
      mtime=$(stat -c %Y "$path" 2>/dev/null) || continue
      (( mtime < BOOT_TS )) && continue
      if (( mtime > newest_mtime )); then
        newest_mtime=$mtime
        newest_path=$path
      fi
    done < <(find "$APP_DIR" -path "$STABLE_DIR" -prune -o -type f -name "$name" -print0 2>/dev/null)

    if [[ -n "$newest_path" && "$newest_path" != "${CURRENT_TARGET[$name]:-}" ]]; then
      link="$STABLE_DIR/$name"
      # Relative target so the symlink resolves the same on host, in this
      # container, and in a sidecar container (e.g. IW4MAdmin) regardless of
      # where the app/ volume is mounted.
      rel_target=$(realpath --relative-to="$STABLE_DIR" "$newest_path")
      rm -f "$link"
      ln -s "$rel_target" "$link"
      CURRENT_TARGET[$name]=$newest_path
      echo "[log-watcher] $name -> $rel_target"
    fi
  done

  sleep "$POLL_INTERVAL"
done
