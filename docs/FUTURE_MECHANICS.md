# Future Mechanics Design Document

This document outlines design proposals for three future gameplay mechanics for **Raiders of the Lost Temple**. None of these are implemented yet.

---

## 1. Expanded Whip Utility

Currently, the whip (`Player.use_whip()`) performs a 4.5 m forward raycast and triggers `on_whipped()` on `WallLever`s or `interact()` on non-pushable interactables.

### Proposed Features
- **Item Snatching (Distance Pickup):**
  - Hitting a `carryable` item (`Torch`, `GoldenIdol`, or `CollectibleScarab`) with the whip pulls it along the whip trajectory straight into the player's `carry_slot` (or collects it).
  - Visual: Tween the item's `global_position` to the player over `0.15s` synced with the `WhipEffect` retracting.
- **Block Yank (1-Tile Pull):**
  - Whipping a `PushableBlock` could apply a short inward impulse (`push(-forward_dir, 2.5)`) instead of grabbing it, letting players pull a block out of a corner or off a pressure plate from a safe distance.
- **Whip Swinging (Gap Traversal):**
  - Add `WhipHook` anchor nodes above `CrumblingFloor` chasms or spike pits.
  - When a player whips a `WhipHook`, transition the player into a brief pendulum swing state (`is_swinging = true`), carrying them across the gap along an arc before releasing.

---

## 2. Dash / Dodge Roll

A quick evasion move to help players weave through `DartTrap`s, `SpikeTrap`s, and the `GiantBoulder` chase.

### Proposed Design
- **Input:** Double-tap movement or dedicated button (e.g., `Shift` / Gamepad `B` / `Circle`), mapped per player (`p1_dash`..`p4_dash`).
- **Behavior:**
  - Burst velocity (`speed * 2.4`) in the current movement direction (or facing direction if idle) for `0.18s`.
  - Grant brief invulnerability frames (`is_invulnerable = true` for `0.16s`) against projectiles and floor spikes, but **not** against the `GiantBoulder` (or reduced knockback).
  - **Cooldown:** `0.9s` between dashes to prevent spamming through puzzles.
- **Visual & Audio Feedback:**
  - Tilt `mesh_root` forward into a dive/roll (`rotation.x` tween), spawn 2–3 dust puffs behind the player's feet, and play a cloth/whoosh SFX via `AudioManager`.

---

## 3. Co-op Revive Mechanic

Currently, a player who reaches `0` HP remains defeated until the level ends or all players fall. A revive mechanic rewards teamwork during tough rooms and the boulder escape.

### Proposed Design
- **Downed State (2+ Players):**
  - In solo play (`players.size() == 1`), reaching `0` HP still triggers Game Over immediately.
  - In co-op (`2–4` players), a defeated player enters `is_downed = true` instead of permanent death, displaying a pulsing floating revive icon (`[E] Revive`) above them.
- **Revive Action:**
  - A living teammate standing within `1.8m` holds `interact` (`E` / Gamepad `A`) for `1.5s`.
  - A world-space circular progress ring fills up above the downed player. Moving out of range or releasing `interact` cancels the progress.
  - On completion, the downed player stands up with `1 HP` and `1.5s` of spawn invulnerability.
- **Escape Zone Rule:**
  - Downed players cannot enter the `EscapeZone` on their own—teammates must either revive them first or leave them behind if the boulder is too close (or require all living players to escape, as currently implemented).
