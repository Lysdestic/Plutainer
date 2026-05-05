# Plutainer: Dockerized Plutonium, IW4x & Alterware Game Servers

This repository contains the necessary files to build and run dedicated game servers for Plutonium, IW4x, and Alterware using Docker. The image is designed to be flexible and configurable through environment variables.

The container is available on GitHub Container Registry: `ghcr.io/ayymoss/plutainer:latest`

## Overview

The primary goal of this Docker image is to simplify the setup and management of dedicated servers for the following games:

* **Plutonium:**
  * T4 (Call of Duty: World at War) - `t4mp`, `t4sp`
  * T5 (Call of Duty: Black Ops) - `t5mp`, `t5sp`
  * T6 (Call of Duty: Black Ops II) - `t6mp`, `t6zm`
  * IW5 (Call of Duty: Modern Warfare 3) - `iw5mp`
* **IW4x:** (Call of Duty: Modern Warfare 2) - `iw4x`
* **Alterware:**
  * T7x (Call of Duty: Black Ops III) - `t7x`

The container includes the installation of Wine, Plutonium, IW4x, and Alterware launchers, and sets up a non-root user for enhanced security.

## Prerequisites

Before you can use this Docker image, you will need to have the base game files for the server you wish to host. This image does not provide any copyrighted game files. You must legally own the games.

You will also need to have Docker and Docker Compose installed on your system.

## Getting Started: `docker-compose.yml`

Instead of using a long `docker run` command, it is highly recommended to use `docker-compose` to manage your server. See [EXAMPLE-docker-compose.yml](EXAMPLE-docker-compose.yml) for complete examples.

## Configuration

### Environment Variables

The container is configured entirely through environment variables. You must specify one of `PLUTO_GAME`, `IW4X_GAME`, or `ALTER_GAME`.

#### General Variables

| Variable | Description | Default |
| --- | --- | --- |
| `PLUTO_GAME` | The Plutonium game to run. **Required** for Plutonium. | |
| `IW4X_GAME` | The IW4x game to run. Must be `iw4x`. **Required** for IW4x. | |
| `ALTER_GAME` | The Alterware game to run. Must be `t7x`. **Required** for Alterware. | |

See above for the game tags to use. (eg, `t6zm`)

#### Plutonium Variables

| Variable | Description | Default |
| --- | --- | --- |
| `PLUTO_SERVER_KEY` | **Required.** Your server key from the Plutonium website. | |
| `PLUTO_CONFIG_FILE` | **Required.** The filename of your server's configuration file. | |
| `PLUTO_SERVER_NAME` | The name of your server. | "Plutonium Docker Server" |
| `PLUTO_PORT` | The network port for the server. | Game-specific default (e.g., 4976 for T6) |
| `PLUTO_MOD` | The name of the mod folder to load. Omit this if no mod needed. | |
| `PLUTO_MAX_CLIENTS` | **T5 Only!** The maximum number of players allowed. | |
| `PLUTO_AUTO_UPDATE` | Set to `"false"` to prevent the container from checking for updates on start. | `true` |
| `PLUTO_HEALTHCHECK` | Set to `"false"` to disable the health check. | `true` |
| `PLUTO_SKIP_SEED` | Set to `"true"` to skip first-run config seeding. See [Bundled Config Seeds](#bundled-config-seeds). | `false` |
| `PLUTO_EXTRA_ARGS` | Allows you to extend the start param. | |

(eg. `- "PLUTO_EXTRA_ARGS=+set SOMETHING=1 +set SOMETHING_ELSE=FOO"`)

#### IW4x Variables

| Variable | Description | Default |
| --- | --- | --- |
| `IW4X_CONFIG_FILE` | **Required.** The filename of your server's configuration file. | |
| `IW4X_SERVER_NAME` | The name of your server. | "IW4x Docker Server" |
| `IW4X_PORT` | The network port for the server. | `28960` |
| `IW4X_MOD` | The name of the mod folder to load. Omit this if no mod needed. | |
| `IW4X_AUTO_UPDATE` | Set to `"false"` to prevent the container from checking for updates on start. | `true` |
| `IW4X_HEALTHCHECK` | Set to `"false"` to disable the health check. | `true` |
| `IW4X_NET_LOG_IP` | The IP address and port for remote netlogging. | |
| `IW4X_EXTRA_ARGS` | Allows you to extend the start param. | |

#### Alterware Variables

| Variable | Description | Default |
| --- | --- | --- |
| `ALTER_CONFIG_FILE` | **Required.** The filename of your server's configuration file (placed in `zone/`). | |
| `ALTER_SERVER_NAME` | The name of your server. | "T7x Docker Server" |
| `ALTER_PORT` | The network port for the server. | `27017` |
| `ALTER_MOD` | The Steam Workshop ID of the mod to load. Omit this if no mod needed. | |
| `ALTER_AUTO_UPDATE` | Set to `"false"` to prevent the container from checking for updates on start. | `true` |
| `ALTER_HEALTHCHECK` | Set to `"false"` to disable the health check. | `true` |
| `ALTER_SKIP_SEED` | Set to `"true"` to skip first-run config seeding. See [Bundled Config Seeds](#bundled-config-seeds). | `false` |
| `ALTER_EXTRA_ARGS` | Allows you to extend the start param. | |

***

### Volumes and Configuration Files

To persist your server configurations and provide the necessary game files, you must use Docker volumes.

* **Game Files:** You need to mount your host machine's game files directory into the container at `/home/plutainer/gamefiles`. It is highly recommended to mount this as read-only (`:ro`) to prevent the container from modifying your base game files.
* **Config Files:** Your server's `.cfg` files should be included in the default expected locations for the games. Mount `/home/plutainer/app`. The expected relative game config defaults are...
  * **IW4x:** `./gamefiles/userraw/`
  * **Plutonium T4 (WaW):** `./gamefiles/main/`
  * **Plutonium T5 (BO1):** `./plutonium/storage/t5/`
  * **Plutonium IW5 (MW3):** `./gamefiles/admin/`
  * **Plutonium T6 (BO2):** `./plutonium/storage/t6/`
  * **Alterware T7x (BO3):** `./gamefiles/zone/`

### Bundled Config Seeds

To make first-run setup painless, the image bundles default configs from community repos and copies them into the bind-mounted `app/` volume on container start. Files that already exist are **never overwritten** — existing user configs are always kept as-is.

| Game | Source repo |
| --- | --- |
| Plutonium T4 | [xerxes-at/T4ServerConfigs](https://github.com/xerxes-at/T4ServerConfigs) |
| Plutonium T5 | [xerxes-at/T5ServerConfig](https://github.com/xerxes-at/T5ServerConfig) |
| Plutonium T6 | [xerxes-at/T6ServerConfigs](https://github.com/xerxes-at/T6ServerConfigs) |
| Plutonium IW5 | [xerxes-at/IW5ServerConfig](https://github.com/xerxes-at/IW5ServerConfig) |
| Alterware T7x | [Dss0/t7-server-config](https://github.com/Dss0/t7-server-config) (includes the `t7x/lobby_scripts/` required for `sv_lobby_mode` to work) |

To opt out — for example if you manage configs entirely yourself and don't want any default files appearing in your bind mount — set `PLUTO_SKIP_SEED=true` (Plutonium) or `ALTER_SKIP_SEED=true` (Alterware).

The seed snapshot is frozen at image build time. Pulling a newer image only seeds files that don't yet exist in your bind mount, so the upstream repo never silently overwrites your edits.

***

### Permissioning

#### Mount Permissions

When you mount volumes from your host machine into the container, the `plutainer` (with UID `1000`) needs to have the appropriate permissions to read and write to those directories. If the ownership on your host directories is incorrect, the server may fail to start or be unable to save data.

On many desktop Linux distributions (like Debian), the first user you create is automatically assigned UID `1000`. If you are that user, you may not need to do anything. However, if you created the directories as `root` (e.g., using `sudo mkdir`), you will need to update their ownership.

#### How to Fix Permissions

To ensure the container has the correct access, you should change the ownership of your persistent data directory to match the container's user. Run the following command on your host machine, adjusting the path to match your setup:

```sh
sudo chown -R 1000:1000 /opt/pluto-servers/t6zm-server-1/
```

The `-R` flag applies the ownership recursively, ensuring all files and sub-folders have the correct permissions. While the container only needs to *read* the game files, applying correct ownership to that volume as well is good practice to avoid any potential read-related issues.

***

### RCON CLI

The container includes a built-in RCON client for sending commands to your server. It automatically detects the game type, port, and RCON password from your configuration — no extra setup needed.

```sh
# Send a single command
docker exec <container_name> rcon-cli status

# Open an interactive RCON session
docker exec -i <container_name> rcon-cli
```

Your server configuration file must have `rcon_password` set for `rcon-cli` to work.

***

### Advanced: IW4MAdmin & RCON

Connecting a containerized IW4MAdmin to your Plutainer server requires special network configuration due to the way Docker handles container-container networking via its proxy.

This guide applies to a specific scenario:

* Your Plutainer game server is running in a container.
* IW4MAdmin is running in a **separate container on the same host**, but on a **different Docker bridge network**.

Do **not** run IW4MAdmin from within the same bridge network as your Plutainer containers.
In this setup, when IW4MAdmin sends an RCON command, the game server sees the request as coming from its own network's **gateway IP**, not the IW4MAdmin container's IP.

#### Solution: Whitelist the Gateway

You must whitelist your Plutainer container's network gateway IP for RCON commands.

**Example:** Consider this `docker-compose.yml` network configuration:

```yaml
networks:
  pluto-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.26.10.0/24
          gateway: 172.26.10.1 # <--- This is the gateway IP
```

If your game server is attached to `pluto-net`, you must add `"172.26.10.1"` to your server's `.cfg` RCON whitelist directive to grant IW4MAdmin access.

This issue does **not** occur if you are running IW4MAdmin directly on the host machine (bare-metal) or on an entirely different machine.

***

### Healthcheck

The container includes a robust health check script that verifies the server is running and responsive. It works by:

1. Detecting the game type and port.
2. Locating your server configuration file.
3. Extracting your `rcon_password` from the config.
4. Sending an RCON `status` command to the server.
5. Checking for a valid response.

The health check is enabled by default. You can disable it by setting the corresponding environment variable (`PLUTO_HEALTHCHECK`, `IW4X_HEALTHCHECK`, or `ALTER_HEALTHCHECK`) to `"false"`. This can be useful for debugging or if you do not wish to set an RCON password.

Please note that for the healthcheck to work correctly, games that support RCon whitelists need to have localhost permitted and/or "127.0.0.1"

To have your servers restarted automatically, simply add [Auto Heal](https://github.com/willfarrell/docker-autoheal) to the compose.

***

### Support?

Discord Support: https://discord.gg/PjrFw4tNES

Please note that I will not be supporting Plutonium-specific issues. There is an expectation that you're already familiar with Docker. If you're brand new, please visit https://docs.docker.com/get-started/

This Discord is to be specific to Plutainer and its setup and configuration (including IW4MAdmin).

***

#### Credits

- Corey, for a production testing ground @ https://cukservers.net/
- HGM, for the name 'Plutainer' @ https://hgmserve.rs/
