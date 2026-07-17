# Neovim in the Browser

<img width="1960" height="1120" alt="Screenshot from 2025-08-30 20-58-16" src="https://github.com/user-attachments/assets/a84ab3c0-176b-4b3d-a413-5586fde4c7e3" />

`nvim-server` is a web frontend for [Neovim](https://neovim.io/) designed around
allowing the user to run Neovim anywhere you have a browser.

Note this project was vibe coded over a two day period, and I'm at the point in
which I believe I have a minimal viable product. Next steps include addressing
roadmap items and trying to refactor / understand parts of the code I had the
AI generate. Right now I'd consider nvim-server an MVP based on my personal
requirements.

## Features

- One server can connect to multiple clients.
- Full clipboard integration using a custom clipboard provider.
- GPU acceleration.

## Run as a self-contained container (recommended)

The Docker image bundles everything — Neovim, the toolchain your config needs, and
the web frontend — into a single container that boots its own Neovim and connects
the browser automatically. No external Neovim, no sidecars.

```
docker run -d --name nvim-server \
  -p 9998:9998 \
  -v /path/to/your/nvim/config:/config/nvim \
  -v /path/to/data:/data \
  ghcr.io/sewsam/nvim-server:latest
```

Then open `http://localhost:9998` — it auto-connects to the bundled Neovim (no
address to type). Volumes:

- **`/config/nvim`** — your Neovim config (e.g. your dotfiles' `nvim/.config/nvim`).
  This is a plain directory on the host: manage it with `git` yourself (clone, pull,
  push) — the container never holds git credentials and does not touch your remote.
- **`/data`** — persistent plugins, Mason LSP/tools, treesitter parsers and state.
  On first start the container runs `Lazy sync` + Mason installs into this volume
  (needs internet the first time); later starts are fast and offline.

The web port is configurable: change the published port and set `WEB_PORT` to match
(e.g. `-p 8080:8080 -e WEB_PORT=8080`).

The web editor has **no built-in authentication** — it is effectively a shell on the
host. Only expose it behind a reverse proxy / VPN that provides auth and TLS. (TLS is
also required for clipboard integration; see below.)

### Unraid

An Unraid Community-Applications template lives at
[`unraid/nvim-server.xml`](unraid/nvim-server.xml). Add this repo as a template
source (CA → *Add container template repositories*, or paste the raw XML URL) and the
WebUI port plus both volumes come pre-filled — no manual container building required.

### Publishing / pulling from GHCR

Pushing to `main` (or a `v*` tag) runs [`.github/workflows/docker.yml`](.github/workflows/docker.yml),
which builds and pushes `ghcr.io/sewsam/nvim-server` using the repo's built-in
`GITHUB_TOKEN` (no extra secrets). The first publish creates the GHCR package as
**private** — make it public under the repo's *Packages* settings if you want to pull
without authenticating.

## Advanced: run the frontend against an external Neovim

You can also run just the web frontend and point it at a Neovim instance you manage
yourself. First spawn the server:

```
$ ./nvim-server --address 0.0.0.0:9998
```

Then you can go to `http://localhost:9998` and enter the location of a remote
neovim instance. You can optionally pass in the server address as a query
string (e.g. `http://localhost:9998/?server=localhost:9000`) to automatically
connect to your Neovim instance.

Optionally, you can create a systemd unit to automate this entire process:

```
[Unit]
Description=nvim-server

[Service]
ExecStart=nvim-server --address 0.0.0.0:9998
Restart=always

[Install]
WantedBy=default.target
```

Note that if your nvim-server and nvim are on different LANs you may want to
use a secure tunnel to encrypt your neovim RPC traffic.

## Clipboard Support

Clipboard Support requires the user to have nvim-server running behind HTTPS
as browsers block clipboard sharing for HTTP connections.

## Project Background

Before starting this project I wrote a couple of blog posts about Neovim being
a terminal emulator / multiplexer replacement. I may write future posts in the
future elaborating on why Neovim in the browser was my eventual conclusion for
creating an optimal development workflow.

- [Remote Neovim for Dummies](https://kraust.github.io/posts/remote-neovim-for-dummies/)
- [Neovim is a Multiplexer](https://kraust.github.io/posts/neovim-is-a-multiplexer/)

## Roadmap

- Better font rendering support.

## Similar Projects

- [Code Server](https://github.com/coder/code-server) - VSCode in the Browser
- [Glowing Bear](https://github.com/glowing-bear/glowing-bear) - WeeChat in the Browser
- [Neovide](https://github.com/neovide/neovide) - An amazing Neovim GUI that I've been using since 2020.

