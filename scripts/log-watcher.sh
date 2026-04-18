#!/bin/bash
#
# Maintains stable symlinks at /home/plutainer/app/logs/<basename> pointing at
# the active game log for that basename. Game logs move around per game/mod
# (e.g. plutonium/storage/t5/mods/<mod>/logs/games_zm.log) and users create
# arbitrarily named logs (e.g. games_koth.log), which makes IW4MAdmin
# configuration brittle. This watcher surfaces every *.log under app/ in one
# predictable flat directory.
#
# Strategy:
#   - Record container boot time.
#   - Poll app/ for every *.log (excluding app/logs/ itself to avoid cycles).
#   - For each basename, the active log is the one with mtime >= boot time and
#     the newest mtime overall. Stale logs from prior sessions keep their old
#     mtime and are ignored. Collisions across mod dirs resolve to the
#     currently-written file (game only writes one at a time).
#   - Symlinks are relative so they resolve the same from host, this
#     container, or any sidecar container mounting the app/ volume.
#   - Only repoint when target changes (idempotent, no fs churn).
#   - Startup heal: dangling symlinks from prior runs (target removed between
#     restarts) are converted to empty stub files. Preserves presence so a
#     sidecar like IW4MAdmin never sees a missing path and doesn't attempt to
#     create a directory in its place.
#   - Atomic repointing via mv -Tf from a temp symlink so readers never catch
#     the link in a missing or half-written state.
#

APP_DIR=/home/plutainer/app
STABLE_DIR="$APP_DIR/logs"
POLL_INTERVAL="${PLUTAINER_LOG_POLL_INTERVAL:-2}"

if [[ "${PLUTAINER_LOG_SYMLINKS}" == "false" ]]; then
  echo "[log-watcher] disabled via PLUTAINER_LOG_SYMLINKS=false"
  exit 0
fi

mkdir -p "$STABLE_DIR"

# Atomically place a symlink at $link -> $rel_target. Works whether $link
# currently does not exist, is a regular file (legacy stub), or is a symlink.
place_symlink() {
  local link="$1" rel_target="$2"
  local tmp
  tmp=$(mktemp -u -p "$STABLE_DIR" ".$(basename "$link").XXXXXX")
  ln -s "$rel_target" "$tmp"
  mv -Tf "$tmp" "$link"
}

# Startup heal: any dangling symlinks from prior container runs become empty
# stub files so sidecar readers always see a file. If the old target is still
# valid, leave the symlink alone — IW4MAdmin can keep reading continuously
# until a fresh target is identified by the poll loop below.
if compgen -G "$STABLE_DIR/*" > /dev/null; then
  for entry in "$STABLE_DIR"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    if [[ -L "$entry" && ! -e "$entry" ]]; then
      echo "[log-watcher] healing dangling symlink: $(basename "$entry")"
      rm -f "$entry"
      touch "$entry"
    fi
  done
fi

BOOT_TS=$(date +%s)

declare -A CURRENT_TARGET

echo "[log-watcher] started; boot_ts=$BOOT_TS stable_dir=$STABLE_DIR"

while true; do
  declare -A NEWEST_MTIME=()
  declare -A NEWEST_PATH=()

  while IFS= read -r -d '' path; do
    mtime=$(stat -c %Y "$path" 2>/dev/null) || continue
    (( mtime < BOOT_TS )) && continue
    name=$(basename "$path")
    if (( mtime > ${NEWEST_MTIME[$name]:-0} )); then
      NEWEST_MTIME[$name]=$mtime
      NEWEST_PATH[$name]=$path
    fi
  done < <(find "$APP_DIR" -path "$STABLE_DIR" -prune -o -type f -name '*.log' -print0 2>/dev/null)

  for name in "${!NEWEST_PATH[@]}"; do
    path="${NEWEST_PATH[$name]}"
    if [[ "$path" != "${CURRENT_TARGET[$name]:-}" ]]; then
      link="$STABLE_DIR/$name"
      rel_target=$(realpath --relative-to="$STABLE_DIR" "$path")
      place_symlink "$link" "$rel_target"
      CURRENT_TARGET[$name]=$path
      echo "[log-watcher] $name -> $rel_target"
    fi
  done

  unset NEWEST_MTIME NEWEST_PATH
  sleep "$POLL_INTERVAL"
done
