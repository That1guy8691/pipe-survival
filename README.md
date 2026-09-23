# PIPE / Survival

A Godot 4.7 game inspired by the classic growing-pipes screensaver.
Choose Survival, where old trails remain and the last pipe alive wins, or Endless,
where trails disappear when riders die and pipes return inside the same finite cube.
Choose 7, 15, 23, or 31 bots on the title screen; the default is 15.
Choose a 40, 60, 80, or 100-unit cube with the Arena Size dropdown; the default is 60.
Adjust the camera's base field of view from 60° to 110° in Game Options.
Both dropdowns and the Start, Resume, and Back to Title buttons support mouse clicks.
Game Options also lets you choose Solid, Stripes, or Spots for your pipe beside the
color picker. The live 3D preview shows your color and pattern on straight sections
and a curved elbow. Patterns keep the collars plain and stay with your pipe across
rounds and Endless respawns. Bots randomly choose Solid, Stripes, or Spots each round
and retain that pattern when they respawn. Like your name and color, your selection
lasts for the current game session.
Pipes grow from colored, bolted wall inlets distributed across all six faces.
Pickups and bot paths use the outer lanes as well as the center of the cube.
Turn on Auto Mode to watch every pipe steer and boost itself. Completed rounds
restart after five seconds, keeping the selected arena, bot count, and camera view.

## Play in your browser

[Play PIPE / Survival](https://that1guy8691.github.io/pipe-survival/)

No download is needed. Click the game to focus it, then use the controls below.
The browser build uses simpler vertex lighting to reduce shader startup time.
Desktop keeps its existing lighting. Web exports exclude local build artifacts.

## Run the project on desktop

Double-click `Play.cmd` on Windows with Godot 4.7 installed, or open
`project.godot` in Godot 4.7 and press F5. The web build is generated from the
same project when changes are pushed to `main`.

| Control | Action |
| --- | --- |
| Enter / Start Round | Begin a round, or replay after the result |
| W | Pitch up relative to your pipe |
| S | Pitch down relative to your pipe |
| A | Turn left relative to your pipe |
| D | Turn right relative to your pipe |
| Arrow keys | Nudge the camera orbit or look direction |
| C | Cycle chase / first person / overview |
| V in overview | Cycle normal / highlight / bright ends pipe display |
| Tab / Shift+Tab | In overview, highlight the next / previous living pipe; otherwise follow survivors in Auto Mode or after elimination |
| Q / E during a round | Decrease / increase the field of view by 2° |
| F / Auto Mode button | Toggle automatic steering, boost, and round replay |
| H / HUD button | Hide or restore the gameplay interface and all floating labels |
| Hold Shift | Boost your own pipe to twice normal speed |
| Right mouse drag | Orbit in overview |
| Mouse wheel | Zoom in overview |
| Escape | Pause / resume |
| R | Restart Survival; respawn yourself after a crash in Endless |

On touch screens, tap VIEW to change cameras. In overview, PIPES cycles display modes
and NEXT highlights another living pipe.

Endless keeps the cube size fixed. A rider's death clears only that rider's trail;
bots return after a short delay at a safe open wall inlet. After a player crash, press
R or Enter, or use the on-screen Restart Pipe button. This respawns only your pipe in
the current session; surviving pipes, their scores and trails, and the selected cube stay put.
Each rider's score, pickup count, eliminations, and survival streak reset on death.
In Auto Mode your pipe also returns automatically after the same short delay as bots.
If no safe inlet is open yet, the respawn waits for one. Survival remains the default
mode and keeps its original persistent trails and last-pipe-wins ending.

Each WASD turn is triggered once per tap; two turns can be queued, each applied at
the next available grid junction.
Manual rounds start with the familiar Chase camera. C cycles through First Person,
Overview, then back to Chase. Arrow keys adjust the camera orbit or look direction.
Q and E adjust FOV during a round;
the Game Options slider sets its starting value. Camera switching preserves steering
relative to the pipe.
Losing window focus pauses a manually controlled round.
Auto Mode keeps running without focus; Escape still pauses it, including the
five-second result countdown. It starts in a slowly rotating overview. C changes
views. In overview, V switches between the full-color map, a selected-pipe highlight,
and a view with faint trails and brighter pipe ends. Tab / Shift+Tab choose the next
or previous living pipe; in Auto Mode, the camera, score, and boost meter follow it.
Outside overview, Tab / Shift+Tab retain their survivor-follow behavior. If the
followed pipe crashes, the camera follows a survivor.
Switching back to manual returns control to your cyan pipe if it is still alive;
otherwise, R starts a fresh round. Driver changes take effect at the next junction.

The HUD uses larger survivor, score, followed-pipe, and Boost displays. Auto Mode
shows a compact leaderboard that always includes the followed pipe.

Press H for a clean arena view: it hides the HUD, crosshair, notifications, countdown,
results, pipe names, and wall labels. Camera and gameplay controls remain active.
Press H again to restore them. Escape always opens the pause menu; resuming returns
to the chosen HUD setting. Title and pause menus remain usable with HUD off, and
the preference lasts across rounds, restarts, and automatic replay.

Boost lasts about two seconds on a full meter. The boost meter recharges automatically
when not boosting, taking about four seconds from empty to full. Release Shift
after exhausting the meter before boosting again. Speed changes begin at the next
grid junction. Bots have the same boost meter and collision rules.

In first person, the camera rides the growing tip; your own head and name label
are hidden so they do not block the view. Turns follow the rounded elbow path.

## Points

| Action | Points |
| --- | --- |
| Collect a blue orb | 15 |
| Collect a gold orb | 25 |
| Collect a violet orb | 50 |
| Thread a tight near-miss beside a pipe trail | 15 |
| Survive a full second | 1 |
| An opponent crashes into your pipe while you remain alive | 100 |
| Win the round | 250 |

Near-misses count once when you enter a cell beside a pipe trail with at most two
open legal exits; leaving the tight section rearms the bonus. Orbs, near-misses, and
eliminations chain when they happen within four seconds, raising those event rewards
from 1x up to 2.5x. Death or an expired timer ends the combo. Orb colors show their
base value: blue is 15, gold is 25, and violet is 50. Gold is the most common; blue
appears about 20% of the time and violet about 10%, keeping the average near 25
points per orb. Bots weigh value against distance while still favoring open space and
safe routes. Survival and win points stay fixed. Orbs replenish in empty cells. The
leaderboard shows score leaders and always includes you. Self-collisions, head-on
draws, and collisions with an already eliminated owner's pipe award no elimination
credit.
Survival points stop when you die; the last surviving pipe wins regardless of score.

## Rules and initial tuning

- Selectable cube width: 40, 60, 80, or 100 units, using 2-unit cells.
- Arena geometry, spawns, pickups, and cameras use the selected width.
- One human and 7, 15, 23, or 31 local bots, each with a colored, named pipe.
- Pipe body diameter: 1.2 units, with slightly wider joint collars.
- Three cell transitions per second (6 grid units per second); bends follow rounded paths.
- Wall, self-pipe, and other-pipe collisions eliminate a player.
- Simultaneous attempts to enter the same cell eliminate both heads.
- Survival keeps eliminated pipes solid until the next round and ends when at most one
  player remains. A simultaneous final collision is a draw.
- Endless clears eliminated trails, keeps the session running, and respawns bots safely
  inside the selected cube. Each death resets that rider's score and life statistics;
  the session clock and surviving riders continue. Auto Mode respawns your pipe too.
- Both modes use collectible points. No networking or account setup.

The collision model uses occupied grid cells. Visible gaps do not create additional
off-grid routes. Arena faces use a wire grid so overview cameras can see inside.
The initial title backdrop builds a simulated round over successive frames so the
menu can accept input immediately. Starting cancels this work and clears it completely.

## Code

`scripts/simulation.gd` owns rules, spawns, local steering frames, and bot decisions.
`scripts/motion.gd` schedules each pipe independently and manages the boost meter.
`scripts/scoring.gd` owns pickups and point awards.
Endless respawn and trail cleanup use the same simulation and renderer ownership.
`scripts/orb_renderer.gd` draws the collectible gold orbs.
`scripts/pipe_geometry.gd` creates reusable straight and elbow meshes.
`scripts/pipe_renderer.gd` batches permanent pipe sections and animates their growing tips.
`scripts/pipe_inlet.gd` builds the fixed wall fittings at each pipe's origin.
`scripts/camera_rig.gd` owns chase, orbit, and zoom.
`scripts/arena.gd` builds the cube and lighting.
`scripts/game.gd` owns input, round flow, and presentation coordination.
`scripts/hud.gd` draws the interface.

## Focused checks

Run using the Godot 4.7 console executable from this project directory:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/rules_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/startup_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/features_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/endless_mode_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/pipe_patterns_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/arena_sizes_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/inlets_test.gd
```

The opt-in rendered smoke driver uses in-engine input events, captures camera/UI
states, exercises a complete match, and samples larger bot counts. Provide an existing absolute output directory:

```powershell
Godot_v4.7-stable_win64_console.exe --path . -- --qa --qa-dir=C:\path\to\qa-output
```

The smoke driver is never loaded during ordinary play. Procedural meshes and the
standard Godot runtime are the only game dependencies. The UI uses local system fonts.

For rendered pipe-pattern captures, run `tests/pipe_patterns_test.gd` without
`--headless` and add `-- --qa-dir=C:\path\to\qa-output`. The menu pointer test
(`tests/menu_click_test.gd`) also covers pattern selection and the live preview.

The Auto Mode check exercises its actual menu toggle and keyboard controls, follows
bots in first person, completes an AI round, and checks automatic replay and pause:

```powershell
Godot_v4.7-stable_win64_console.exe --path . --script res://tests/auto_mode_test.gd -- --qa-dir=C:\path\to\qa-output
```

The focused HUD check exercises both toggles, a clean view, pause/resume, camera
switching, automatic replay, and rendering at the minimum window size:

```powershell
Godot_v4.7-stable_win64_console.exe --path . --script res://tests/hud_test.gd -- --qa-dir=C:\path\to\qa-output
```

The menu regression test sends pointer presses and releases through GUI hit-testing,
including popup item selection and a smaller window. Run it with a renderer:

```powershell
Godot_v4.7-stable_win64_console.exe --path . --script res://tests/menu_click_test.gd
Godot_v4.7-stable_win64_console.exe --path . --script res://tests/renderer_buffer_test.gd
```

The render-buffer check requires a real renderer; Godot's headless dummy renderer
does not retain the instance transforms this check reads back.
