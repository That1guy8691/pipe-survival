# Public multiplayer deployment

The repository already contains a GitHub Pages workflow at `.github/workflows/pages.yml` for the browser game. The room server cannot run on GitHub Pages; it needs an always-on Linux host that supports Docker and WebSockets.

## 1. Publish the room server

Copy `deploy/Caddyfile.example` to `deploy/Caddyfile` and replace `game.example.com` with a DNS name that points to the server. From the repository root on the host, run:

```sh
docker compose -f deploy/docker-compose.yml up -d --build
```

Caddy terminates HTTPS and forwards WebSocket traffic to the Godot room server. The public endpoint will be:

```text
wss://game.example.com
```

Open TCP ports 80 and 443 on the host. Do not expose the Godot port directly to the internet.

## 2. Point the browser build at the server

Change `application/config/multiplayer_server_url` in `project.godot` to the public endpoint:

```ini
config/multiplayer_server_url="wss://game.example.com"
```

Commit and push that change to `main`. The existing Pages workflow exports the Web build and publishes it automatically.

## 3. Verify

Open the Pages URL in two browser windows. Use **Quick Match** in both, then try a generated private code. Confirm that both clients see the same room and that one leaving does not stop the other.

Keep private room codes, host controls, packet limits, and the TLS boundary enabled when moving beyond a small test group.
