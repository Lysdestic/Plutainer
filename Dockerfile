# Use Debian Trixie as the base (pinned for reproducibility)
FROM debian:trixie

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture and update package lists
RUN dpkg --add-architecture i386 && \
    apt-get update

# Install necessary dependencies, including python3 for the healthcheck
RUN apt-get install -y --no-install-recommends \
    wget \
    gpg \
    ca-certificates \
    tar \
    xz-utils \
    jq \
    python3 \
    xvfb \
    xauth

# Add WineHQ repository key
RUN mkdir -pm755 /etc/apt/keyrings && \
    wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key

# Add WineHQ repository for Debian 13 (Trixie)
RUN wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources

# Update package lists and install Wine, then clean up
RUN apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for running the server
RUN useradd -m plutainer

# Create X11 socket directory for Xvfb (needed before wineboot and at runtime)
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Wine environment: prevent Gecko/Mono install prompts (which hang in
# non-interactive containers), and set virtual display for Xvfb
ENV WINEDLLOVERRIDES="mscoree,mshtml=" \
    DISPLAY=:99

USER plutainer
WORKDIR /home/plutainer/.plutainer

# Initialize Wine prefix during build so it doesn't hang at runtime
RUN Xvfb :99 -screen 0 320x240x24 & \
    sleep 1 && \
    wineboot -u && \
    wineserver -w && \
    pkill -f Xvfb || true && \
    rm -f /tmp/.X99-lock

# Download and extract the updaters
RUN wget https://github.com/mxve/plutonium-updater.rs/releases/latest/download/plutonium-updater-x86_64-unknown-linux-gnu.tar.gz -O plutonium-updater.tar.gz && \
    tar -xzvf plutonium-updater.tar.gz && \
    rm plutonium-updater.tar.gz

# Download iw4x-launcher (asset names vary per release, so query the API).
# Filter: launcher archive only, glibc Linux build, .tar.xz. Excludes the
# "release-tool-*" assets added in v1.1.8-b.16+ that also contain "linux".
RUN IW4X_URL=$(wget -qO- https://api.github.com/repos/iw4x/launcher/releases/latest \
      | jq -r '.assets[] | select(.name | test("^launcher-.*linux-glibc\\.tar\\.xz$")) | .browser_download_url') && \
    wget -O iw4x-launcher.tar.xz "$IW4X_URL" && \
    mkdir -p iw4x-launcher-extract && \
    tar -xJf iw4x-launcher.tar.xz -C iw4x-launcher-extract && \
    BIN=$(find iw4x-launcher-extract -type f \( -name 'iw4x-launcher' -o -name 'launcher' \) | head -n1) && \
    mv "$BIN" iw4x-launcher && \
    rm -rf iw4x-launcher.tar.xz iw4x-launcher-extract && \
    chmod +x iw4x-launcher

# Copy all scripts and the python module into the image
COPY --chown=plutainer:plutainer scripts/ .
RUN chmod +x entrypoint.sh healthcheck.sh plutoentry.sh iw4xentry.sh alterentry.sh log-watcher.sh rcon-cli game-config.sh

# Add rcon-cli to PATH so it can be invoked without a full path via docker exec
USER root
RUN ln -s /home/plutainer/.plutainer/rcon-cli /usr/local/bin/rcon-cli
USER plutainer

# Set the stop signal to allow graceful shutdown
STOPSIGNAL SIGKILL

# Add the healthcheck instruction
HEALTHCHECK --interval=1m --timeout=10s --start-period=1m --retries=3 \
  CMD ./healthcheck.sh

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
