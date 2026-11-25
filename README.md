# Raiders of the Lost Temple 🏛️💎

A 2.5D isometric puzzle-adventure game for 1–4 players in the spirit of *Minecraft Dungeons* and *Raiders of the Lost Ark / Indiana Jones*. Built for **Godot 4.7**.

---

## 🪨 Pushable & Pullable Stone Blocks (`PushableBlock`)

You can move the ancient sandstone blocks in two smooth ways:
1. **Walk straight into the block:** When you run or walk against the block, your character automatically pushes it forward in front of them with smooth friction.
2. **Grab & Pull/Push (`E` / Gamepad `A`):** Press **E** (or **A** on a gamepad) next to the block to grab onto it. You can now both **push and pull (walk backward)** the block with you! Press **E** again to release.
   * Place blocks on pressure plates to hold stone doors open when playing solo, or use them as a shield against poison dart traps!

---

## 🎥 Camera Rotation & Enclosed Temple Walls

1. **🔄 360° Free & Stepped Camera Rotation:**
   * **Keyboard:** Press **Q** to rotate the camera 45° counter-clockwise, or **R** (alt. **C**) for 45° clockwise. Hold for smooth continuous rotation!
   * **Mouse:** Hold **Right Mouse Button (RMB)** and drag the mouse left/right to freely rotate the camera around the adventurers. You can also use the **Scroll Wheel** to step-rotate!
   * **Gamepad:**
     * **Right Analog Stick:** Smooth stepless orbital rotation.
     * **LB / RB (Shoulder Bumpers):** Snap-rotate 45° left or right.
   * **Dynamic Controls:** Player movement direction automatically adapts to the camera's current angle – **W** always moves upward on the screen regardless of how you rotate the camera!

2. **🧱 Full Temple Walls & Occlusion Transparency:**
   * All chambers, corridors, and sanctuaries in the levels are now completely enclosed by solid sandstone walls with doorways.
   * **Smart Occlusion Fade:** When you rotate the camera and a wall comes between the camera and the players, the wall automatically fades to semi-transparent so you never lose sight of your character!

---

## 🗺️ The Temple Campaign (4 Distinct Levels)

* **💀 Level 1: The Catacombs:** Braziers, alternating silent spike traps, poison dart corridors, and dual wall levers.
* **🪞 Level 2: Chamber of Mirrors:** Skylight sunbeam reflections through rotating mirrors onto solar crystals and twin sun seals.
* **🌗 Level 3: Vault of Twin Moons:** Celestial Sun/Moon phase-shifting obelisks, astral bridges over the chasm, phase forcefield vaults, and sweeping flame spinners.
* **🏛️ Level 4: The Golden Idol (Finale):** Pressure plates, poison darts, smashable urns, the Golden Idol of Ra, and the collapsing boulder escape!

---

## 👥 Local Couch Co-op & 🌐 Online / LAN Co-op (1–4 Players)

* **Local Shared-Screen Co-op:** Choose **1 to 4 players** and any **Starting Level** directly from the main menu, or drop in mid-game with `Enter` / Gamepad `A`.
* **🌐 Online / LAN Co-op (`ENetMultiplayerPeer`):** Click **🌐 Online / LAN Co-op** on the Main Menu to play across separate PCs, each with your own independent camera and full `WASD + E + Space + Shift` (or Controller) controls:
  * **Host Room & Room Codes:** Click **Create Room** to host on UDP port `7777` and copy your 8-character **Room Code** (e.g. `C0A8-012A`).
  * **Join Room:** Paste the Host's **Room Code**, LAN IPv4, VPN IP (Tailscale / Radmin VPN / ZeroTier), or public IP (with UDP `7777` forwarded on the host router) and click **Connect to Room**.
  * **1-Click Localhost Test:** Open two game windows on one PC, click **Create Room** in Window 1, and click **Quick Join Local PC** in Window 2!
* **Dynamic Co-op Difficulty:** Traps, Guardian Seal plates, and the Finale boulder dynamically scale to match your active party size (1P–4P).

---

## ⬇ In-Game Auto-Updater (`main` Branch)

* The Main Menu automatically checks `John123123123123/Puzzle-game` (`main` branch) in the background and highlights **`⬇ Update Available!`** whenever new content is pushed.
* Click **`⬇ Update Game`** on the Main Menu to view the latest commit message, author, and timestamp, and update in 1 click. Every mode updates the **whole game** (scripts, scenes, shaders, `project.godot`, autoloads, Godot's class/UID caches, and for exported builds the executable itself):
  * **Git Clones (`.git` + `git`):** `git fetch`, then a fast-forward of `main`. It never touches other branches without asking (*Switch to main*), offers to stash local edits, only rebases diverged local commits after confirmation (aborting cleanly on conflict), and finally runs `--headless --import` so new `class_name` scripts and UIDs work on restart.
  * **ZIP-Downloaded Folders (no `git` required):** Downloads the archive **pinned to the checked commit**, rejects unsafe paths, stages everything first, then swaps files in with a backup (full rollback on any failure), removes files deleted upstream, and re-imports the project.
  * **Standalone Exported Builds:** The `build-main` GitHub Action (`.github/workflows/build-main.yml`) exports full Windows/Linux/macOS packages for every push to `main` and publishes them (with SHA-256 checksums) on the `latest-main` release. The updater downloads the package for your platform, verifies the checksum, stages it next to the game, and swaps the executable + `.pck` on restart (with rollback). The install folder must be writable.
  * **Private repository:** Git uses your normal credentials. For ZIP/standalone installs the updater uses a token from `user://updater_auth.cfg`, `GITHUB_TOKEN` / `GH_TOKEN`, or `gh auth token` (the token is only sent to `api.github.com`, never to download redirects). You can also paste one into the updater dialog.
* The updater dialog cannot be closed (and levels cannot be started) while an update is being installed.
* Click **`🚀 Restart Game Now`** after updating to relaunch immediately with all new levels, scripts, and visuals.

---

## 🎮 Controls

| Action | Keyboard | Gamepad |
| :--- | :--- | :--- |
| **Player 1 / Online** | **W / A / S / D** (Move / Push block)<br>**E** (Grab block / Carry / Interact)<br>**Space** (Whip)<br>**Shift / F** (Dodge Roll)<br>**G / Tab / Middle-Click** (Co-op Ping) | **Left Stick** (Move / Push)<br>**A / Cross** (Grab / Interact)<br>**X / Square** (Whip)<br>**B / Circle** (Dodge Roll)<br>**Y / Triangle** (Co-op Ping) |
| **Player 2 (Local)** | **Arrow Keys** (Move)<br>**Enter** (Grab / Interact)<br>**Right Shift** (Whip)<br>**/** (Dodge Roll)<br>**. / Numpad 0** (Co-op Ping) | **Left Stick (Controller 2)**<br>**A / X / B / Y** |
| **Players 3 & 4** | - | **Controllers 3 & 4** (Stick + A/X) |
| **Rotate Camera** | **Q / R** (or hold **Right Mouse Button** and drag) | **Right Stick** / **LB & RB** |
| **Menu** | **ESC** | **Start / Menu** |

---
