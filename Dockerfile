# syntax=docker/dockerfile:1

########################################
# Build stage: compile the Go binary   #
########################################
FROM golang:1.24.6-bookworm AS build

ARG VERSION=dev
WORKDIR /src

# Cache module downloads first.
COPY go.mod go.sum ./
RUN go mod download

# Build the fully self-contained binary (static assets are go:embed-ed).
COPY . .
RUN CGO_ENABLED=0 go build -ldflags "-X main.version=${VERSION}" -o /out/nvim-server .

########################################
# Runtime stage: Neovim + toolchain    #
########################################
FROM debian:bookworm-slim AS runtime

# Neovim release to install (debian's own package is far too old for AstroNvim v6).
# "stable" always resolves to the latest stable release; pin to a vX.Y.Z tag for
# reproducibility if desired.
ARG NVIM_VERSION=stable

# Toolchain required by the AstroNvim config: lazy.nvim (git), Mason LSP installers
# (node/npm, python), treesitter parser compilation (build-essential), and the
# telescope/CLI helpers (ripgrep, fd, fzf). unzip/curl/ca-certificates support
# downloading Neovim + Mason packages. tini reaps zombies and forwards signals.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git tar unzip \
        build-essential \
        nodejs npm \
        python3 python3-pip python3-venv \
        ripgrep fd-find fzf \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    # debian ships fd as "fdfind" and bat as "batcat"; expose the expected names.
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# Install Neovim from the official linux x86_64 release tarball into /opt.
RUN curl -fL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
        -o /tmp/nvim.tar.gz \
    && tar -xzf /tmp/nvim.tar.gz -C /opt \
    && ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim.tar.gz \
    && nvim --version

# XDG layout: config is a user-managed volume; data/state/cache persist plugins,
# Mason tools, treesitter parsers and shada across restarts.
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data/share \
    XDG_STATE_HOME=/data/state \
    XDG_CACHE_HOME=/data/cache \
    WEB_PORT=9998

RUN mkdir -p /config /data/share /data/state /data/cache

COPY --from=build /out/nvim-server /usr/local/bin/nvim-server
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/config", "/data"]
EXPOSE 9998

LABEL org.opencontainers.image.source="https://github.com/sewsam/nvim-server" \
      org.opencontainers.image.description="Self-contained web Neovim (AstroNvim) — single container, unraid-ready" \
      org.opencontainers.image.licenses="MIT" \
      net.unraid.docker.webui="http://[IP]:[PORT:9998]/" \
      net.unraid.docker.icon="https://raw.githubusercontent.com/sewsam/nvim-server/main/server/static/neovim.svg"

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
