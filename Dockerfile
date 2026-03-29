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
    python3

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
USER plutainer
WORKDIR /home/plutainer/.plutainer

# Download and extract the updaters
RUN wget https://github.com/mxve/plutonium-updater.rs/releases/latest/download/plutonium-updater-x86_64-unknown-linux-gnu.tar.gz -O plutonium-updater.tar.gz && \
    tar -xzvf plutonium-updater.tar.gz && \
    rm plutonium-updater.tar.gz

RUN wget https://github.com/iw4x/launcher/releases/latest/download/iw4x-launcher-x86_64-unknown-linux-gnu.tar.gz -O iw4x-updater.tar.gz && \
    tar -xzvf iw4x-updater.tar.gz && \
    rm iw4x-updater.tar.gz && \
    chmod +x iw4x-launcher
    # Because for some reason they decided to archive it without execute permissions...

# Copy all scripts and the python module into the image
COPY --chown=plutainer:plutainer scripts/ .
RUN chmod +x entrypoint.sh healthcheck.sh plutoentry.sh iw4xentry.sh rcon-cli game-config.sh

# Set the stop signal to allow graceful shutdown
STOPSIGNAL SIGTERM

# Add the healthcheck instruction
HEALTHCHECK --interval=1m --timeout=10s --start-period=1m --retries=3 \
  CMD ./healthcheck.sh

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
