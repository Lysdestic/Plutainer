# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Plutainer is a Docker image for running Plutonium and IW4x dedicated game servers (Call of Duty titles: T4/WaW, T5/BO1, T6/BO2, IW5/MW3, IW4x/MW2). It uses Wine on Debian to run the Windows game server binaries, configured entirely via environment variables.

## Build & Test

```bash
# Build the Docker image locally
docker build -t plutainer .

# Run a Plutonium container example
docker run -e PLUTO_GAME=t6zm -e PLUTO_SERVER_KEY=<key> -e PLUTO_CONFIG_FILE=dedicated.cfg \
  -v /path/to/game_files:/home/plutainer/gamefiles:ro \
  -v ./server-data:/home/plutainer/app \
  -p 4976:4976/udp plutainer

# Run an IW4x container example
docker run -e IW4X_GAME=iw4x -e IW4X_CONFIG_FILE=server.cfg \
  -v /path/to/game_files:/home/plutainer/gamefiles:ro \
  -v ./server-data:/home/plutainer/app \
  -p 28960:28960/udp plutainer
```

There are no automated tests or linters. The CI pipeline (`.github/workflows/docker-publish.yml`) builds and pushes to `ghcr.io` on pushes to `main` and on releases.

## Architecture

Everything runs as the `plutainer` user from `/home/plutainer/.plutainer`.

1. **`entrypoint.sh`** — Dispatcher that detects game type via `PLUTO_GAME` or `IW4X_GAME` env var and delegates to the appropriate entrypoint script.

2. **`plutoentry.sh`** — Plutonium server entrypoint. Symlinks game-specific files from the read-only gamefiles mount, runs the plutonium-updater, validates env vars, resolves game-specific defaults, then `exec`s `wine bin/plutonium-bootstrapper-win32.exe`.

3. **`iw4xentry.sh`** — IW4x server entrypoint. Similar flow: symlinks game files, runs iw4x-launcher for updates, validates env vars, then `exec`s `wine iw4x.exe`.

4. **`game-config.sh`** — Shared shell library sourced by all other scripts. Single source of truth for game detection, port defaults, config path resolution, and RCON password extraction.

5. **`healthcheck.sh`** — Sources `game-config.sh`, then uses `pyquake3.py` to send an RCON `status` command. Can be disabled with `PLUTO_HEALTHCHECK=true` or `IW4X_HEALTHCHECK=true`.

6. **`rcon-cli`** — Python script providing interactive and one-shot RCON access via `docker exec`. Calls `game-config.sh` to resolve port/credentials. Supports both Plutonium and IW4x.

7. **`pyquake3.py`** — Python 3 Quake 3 protocol library (UDP). Used by the health check and `rcon-cli` for RCON queries.

## Game-Specific Behavior

For Plutonium, `BASE_GAME` is derived by stripping the last two chars from `PLUTO_GAME` (e.g., `t6zm` → `t6`). This drives:

- **Default ports**: iw4x→28960, iw5→27016, t4/t5→28960, t6→4976
- **Config file paths**: t4→`app/gamefiles/main/`, iw5→`app/gamefiles/admin/`, iw4x→`app/gamefiles/userraw/`, others→`app/plutonium/storage/{base_game}/`
- **Command args**: iw5 uses `+set sv_config` and `+start_map_rotate`; others use `+exec` and `+map_rotate`
- **Game file symlinks** differ per base game (see `plutoentry.sh` case statement)

## Container Layout

- `/home/plutainer/gamefiles` — bind-mounted read-only game files from host
- `/home/plutainer/app` — persistent volume (gamefiles symlinks, plutonium data, configs, logs)
- `/home/plutainer/.plutainer` — working directory containing scripts, updaters, and pyquake3
