# Multiplayer foundation

Pipe Survival's first online slice uses an authoritative Godot room server and a browser-safe WebSocket client.

## Current rules

- Endless rooms accept up to 8 human players by default and can expand to 10.
- The simulation reserves 32 actor slots. Empty human slots are represented by bots so the arena stays active.
- A player join replaces a bot slot and gets a fresh safe wall-inlet spawn.
- A player leave or disconnect returns that slot to a bot.
- Survival rooms are closed to late joins after the round starts. Endless rooms stay joinable while they run.
- Round seeds now choose a fresh, deterministic set of wall inlets instead of always opening at the same location.
- Auto Mode is a solo assist; online connections force it off and ignore attempts to re-enable it.
- In Endless multiplayer, a dead player presses `R` or clicks **Respawn Pipe** when ready. Bots still respawn automatically. `R` never resets the shared room.
- Holding Shift boosts movement to twice the normal speed while pressure lasts; releasing it refills pressure.
- Every rider's score resets to zero on death, including bots.

## Local room server

Use the Godot 4.7 console executable from the Engine References entry for this project:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://scripts/multiplayer_server.gd -- --port=8787
```

The server speaks JSON text frames over WebSocket. `PUBLIC` selects the shared public room; any other alphanumeric code creates or joins an isolated private room. Each room has its own authoritative simulation and can keep running while another room is active.

The title screen's **ONLINE** panel has three browser friendly paths:

- **Quick Match** joins `PUBLIC`.
- **Host Public** also joins `PUBLIC`; the first player becomes the room host.
- **Join Private** uses the six character code in the field, generating one when the field is empty.

After the server welcomes a player, full snapshots include rider stats and trail history. The client rebuilds the 3D pipe renderer from that authoritative history, then applies tick moves and join/leave snapshots. Solo play continues to use the local simulation.

Join snapshots include every live trail segment, so a late joiner can see every cell that still blocks movement. Dead riders' trails are removed from the room and its history.

Room hosts have server hooks for locking a room and kicking a peer. Those controls are intentionally protocol-level for now so a moderation UI can be added without changing simulation authority.

## Before public hosting

- Put the WebSocket endpoint behind TLS and use `wss://`. The current server boundary is plain WebSocket so local development stays simple; production should terminate TLS at a reverse proxy and forward to the Godot process.
- Keep private room codes at least four normalized characters; the browser flow generates six characters from an ambiguity-reduced alphabet.
- Enforce the current connection, packet-size, and message-rate limits at the server boundary, then add IP/session quotas at the deployment edge.
- Keep host lock/kick hooks, name moderation, and reporting wired to the server before opening public room creation at scale.
- Treat all client state as untrusted; the server remains authoritative for movement, collisions, scores, and room membership.
