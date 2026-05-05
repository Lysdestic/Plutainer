# Arch base ships pure-WoW64 wine (since wine 10.8-2, June 2025), so 32-bit
# Windows binaries run inside a 64-bit Wine process and use modern 64-bit Linux
# socket syscalls instead of the i386 socketcall(2) multiplexer. Docker 29.4.2's
# default seccomp profile blocks socketcall(2) entirely (CVE-2026-31431, "Copy
# Fail"), which broke Debian/WineHQ-based builds — this base avoids that path.
FROM archlinux:base

RUN pacman -Syu --noconfirm \
        wine \
        xorg-server-xvfb \
        xorg-xauth \
        python \
        jq \
        wget \
        tar \
        xz \
        findutils \
        procps-ng \
        ca-certificates \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN useradd -m plutainer

RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

ENV WINEDLLOVERRIDES="mscoree,mshtml=" \
    DISPLAY=:99

USER plutainer
WORKDIR /home/plutainer/.plutainer

RUN Xvfb :99 -screen 0 320x240x24 & \
    sleep 1 && \
    wineboot -u && \
    wineserver -w && \
    pkill -f Xvfb || true && \
    rm -f /tmp/.X99-lock

RUN wget https://github.com/mxve/plutonium-updater.rs/releases/latest/download/plutonium-updater-x86_64-unknown-linux-gnu.tar.gz -O plutonium-updater.tar.gz && \
    tar -xzvf plutonium-updater.tar.gz && \
    rm plutonium-updater.tar.gz

RUN IW4X_URL=$(wget -qO- https://api.github.com/repos/iw4x/launcher/releases/latest \
      | jq -r '.assets[] | select(.name | test("^launcher-.*linux-glibc\\.tar\\.xz$")) | .browser_download_url') && \
    wget -O iw4x-launcher.tar.xz "$IW4X_URL" && \
    mkdir -p iw4x-launcher-extract && \
    tar -xJf iw4x-launcher.tar.xz -C iw4x-launcher-extract && \
    BIN=$(find iw4x-launcher-extract -type f \( -name 'iw4x-launcher' -o -name 'launcher' \) | head -n1) && \
    mv "$BIN" iw4x-launcher && \
    rm -rf iw4x-launcher.tar.xz iw4x-launcher-extract && \
    chmod +x iw4x-launcher

COPY --chown=plutainer:plutainer scripts/ .
RUN chmod +x entrypoint.sh healthcheck.sh plutoentry.sh iw4xentry.sh alterentry.sh log-watcher.sh rcon-cli game-config.sh

USER root
RUN ln -s /home/plutainer/.plutainer/rcon-cli /usr/local/bin/rcon-cli
USER plutainer

STOPSIGNAL SIGKILL

HEALTHCHECK --interval=1m --timeout=10s --start-period=1m --retries=3 \
  CMD ./healthcheck.sh

ENTRYPOINT ["./entrypoint.sh"]
