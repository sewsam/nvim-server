#!/usr/bin/env bash
# Supervises the two processes that make up the self-contained app:
#   1. a single persistent headless Neovim listening on 127.0.0.1:6666
#   2. the nvim-server web frontend, which dials that Neovim for the browser
# If either process exits, the container exits so the orchestrator can restart it.
set -euo pipefail

NVIM_LISTEN="${NVIM_LISTEN:-127.0.0.1:6666}"
WEB_PORT="${WEB_PORT:-9998}"
NVIM_HOST="${NVIM_LISTEN%:*}"
NVIM_PORT="${NVIM_LISTEN##*:}"

mkdir -p /config "${XDG_DATA_HOME}" "${XDG_STATE_HOME}" "${XDG_CACHE_HOME}"

config_present() {
    [ -d /config/nvim ] && [ -n "$(ls -A /config/nvim 2>/dev/null)" ]
}

# First-run bootstrap: install plugins into the (initially empty) data volume.
# Mason LSP/tool installs continue asynchronously once the live instance starts.
if config_present; then
    if [ ! -d "${XDG_DATA_HOME}/nvim/lazy" ]; then
        echo "[entrypoint] First run detected — syncing plugins with lazy.nvim…"
        nvim --headless "+Lazy! sync" +qa || echo "[entrypoint] Lazy sync reported errors (continuing)."
        echo "[entrypoint] Installing Mason tools (best-effort)…"
        nvim --headless "+MasonToolsInstall" +qa || echo "[entrypoint] Mason install will continue on the live instance."
    fi
else
    echo "[entrypoint] WARNING: /config/nvim is empty. Mount your Neovim config there;"
    echo "[entrypoint]          Neovim will start with its built-in defaults for now."
fi

# Keep a read+write handle open on a fifo so headless Neovim never sees stdin EOF
# and stays running as a persistent RPC server. The web server attaches a UI over
# the --listen socket (a separate channel).
KEEPALIVE=/tmp/nvim-keepalive.$$
mkfifo "$KEEPALIVE"
exec 3<>"$KEEPALIVE"
rm -f "$KEEPALIVE"

echo "[entrypoint] Starting Neovim on ${NVIM_LISTEN}…"
nvim --headless --listen "${NVIM_LISTEN}" <&3 &
NVIM_PID=$!

# Wait for the RPC port to accept connections before starting the web server.
for _ in $(seq 1 120); do
    if (exec 4<>"/dev/tcp/${NVIM_HOST}/${NVIM_PORT}") 2>/dev/null; then
        exec 4>&- 4<&-
        break
    fi
    if ! kill -0 "$NVIM_PID" 2>/dev/null; then
        echo "[entrypoint] Neovim exited before it began listening." >&2
        exit 1
    fi
    sleep 0.5
done

echo "[entrypoint] Starting nvim-server on 0.0.0.0:${WEB_PORT}…"
nvim-server --address "0.0.0.0:${WEB_PORT}" &
SERVER_PID=$!

# Exit (and tear down the sibling) as soon as either process stops.
terminate() {
    trap - TERM INT
    kill "$NVIM_PID" "$SERVER_PID" 2>/dev/null || true
}
trap terminate TERM INT

wait -n "$NVIM_PID" "$SERVER_PID"
terminate
wait 2>/dev/null || true
