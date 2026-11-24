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

## 👥 Player Selection & Starting Level (1–4 Players)

* Choose **1 to 4 players** and any **Starting Level** directly from the main menu.
* **Drop-in:** Press `Enter` or Gamepad `A` to jump straight into the game.
* Press **ESC** at any time during gameplay to return to the menu.

---

## 🎮 Controls

| Action | Keyboard | Gamepad |
| :--- | :--- | :--- |
| **Player 1** | **W / A / S / D** (Move / Push block)<br>**E** (Grab block / Carry / Interact)<br>**Space** (Whip)<br>**Shift / F** (Dodge Roll) | **Left Stick** (Move / Push)<br>**A / Cross** (Grab / Interact)<br>**X / Square** (Whip)<br>**B / Circle** (Dodge Roll) |
| **Player 2** | **Arrow Keys** (Move)<br>**Enter** (Grab / Interact)<br>**Right Shift** (Whip)<br>**/** (Dodge Roll) | **Left Stick (Controller 2)**<br>**A / Cross** (Grab / Interact)<br>**X / Square** (Whip)<br>**B / Circle** (Dodge Roll) |
| **Players 3 & 4** | - | **Controllers 3 & 4** (Stick + A/X) |
| **Rotate Camera** | **Q / R** (or hold **Right Mouse Button** and drag) | **Right Stick** / **LB & RB** |
| **Menu** | **ESC** | **Start / Menu** |

---
