# Future Level Layouts

This document outlines 4 progressive level layout concepts for **Raiders of the Lost Temple**. Each level follows the **"one new mechanic per level"** rule—introducing a single new mechanic in a safe tutorial space before combining it with earlier mechanics.

---

## Level 4: The Chasm of Hooks
**New Mechanic:** **Whip Hooks** — overhead stone/bronze rings you can whip to swing across wide pits.

```text
+--------------------------------------------------+
| [Exit] <--- [AncientDoor]                        |
|                  ^                               |
|             [SunReceiver]                        |
|                  ^                               |
|  [Mirror 2] <--(Beam)-- [Mirror 1]               |
|      ^                      ^                    |
|  (Whip Hook 2)          (Whip Hook 3)            |
|      |                      |                    |
|  [Island B] <===Chasm===> [Island A]             |
|   [Crate]                [Scarab 2]              |
|      ^                      ^                    |
|  [Spike Hall]           (Whip Hook 1 - Safe!)    |
|      |                      |                    |
|   [Start] -----------> [Tutorial Pit]            |
|                        [Scarab 1]                |
+--------------------------------------------------+
```

### Flow
1. **Safe Tutorial Pit:** Near the start, a short gap with a `WhipHook` overhead lets players practice swinging across without harsh punishment.
2. **Split Islands:** Players swing across to **Island A** and **Island B** to rotate `Mirror 1` & `Mirror 2` and push a `PushableBlock` onto a plate that lowers a shutter in front of `SunReceiver`.
3. **Scarabs:** **Scarab 1** by the tutorial pit, **Scarab 2** on Island A, and **Scarab 3** on a small side ledge reached by chaining two `WhipHook` swings.

---

## Level 5: The Wind-Swept Vault
**New Mechanic:** **Wind Vents** — wall vents that blow a visible gust across a lane on a cycle, extinguishing a carried `Torch` unless blocked by a `PushableBlock` or timed between gusts.

```text
+--------------------------------------------------+
|             [Exit]                               |
|               ^                                  |
|         [AncientDoor]                            |
|          /         \                             |
|   [Brazier 1]    [Brazier 2]                     |
|       ^               ^                          |
|  [Wind Lane 2]   [Wind Lane 1]                   |
|  (Push Crate     (Time between                   |
|   to block!)      gusts)                         |
|       ^               ^                          |
|  [Crate Room]    [Torch Pedestal]                |
|   [Scarab 2]      [Scarab 1]                     |
|       \               /                          |
|        [Safe Gust Demo] <-- (1st Wind Vent,      |
|               ^              non-lethal!)        |
|            [Start]                               |
+--------------------------------------------------+
```

### Flow
1. **Safe Gust Demo:** A single `WindVent` blows across the entry hall right next to a `Torch` pedestal—players immediately see the gust and learn it extinguishes the torch without lethal stakes.
2. **Right Lane (Timing):** Carry the lit `Torch` through `Wind Lane 1` between gusts to light `Brazier 2`.
3. **Left Lane (Crate Shield):** `Wind Lane 2` blows continuously, so players push a `PushableBlock` in front of the vent to block the wind and safely carry the `Torch` to `Brazier 1`.
4. **Scarabs:** **Scarab 1** near the torch pedestal, **Scarab 2** in the crate room, and **Scarab 3** in a side alcove behind a `DartTrap` + `WindVent` combo.

---

## Level 6: The Shifting Causeway
**New Mechanic:** **Sliding Stone Bridges** — large floor slabs over chasms that extend/retract when a `WallLever` or `PressurePlate` is triggered, or cycle on a rhythm.

```text
+--------------------------------------------------+
| [Exit] <--- [AncientDoor] <--- [Brazier]         |
|                                    ^             |
|   [Island C] <---(Bridge 3)---> [Island D]       |
|   [Scarab 2]     (Lever-locked)  [Torch]         |
|       ^                                          |
|   (Bridge 2)  <-- Held by [Plate A] on Island A  |
|       |                                          |
|   [Island A] <---(Bridge 1)---> [Island B]       |
|   [Crate]       (Timed cycle)   [WallLever]      |
|       ^                                          |
|    [Start]                                       |
|   [Scarab 1]                                     |
+--------------------------------------------------+
```

### Flow
1. **Timed Bridge 1:** Players cross a cycling `SlidingBridge` between **Island A** and **Island B** to learn how bridges extend and retract.
2. **Plate-Held Bridge 2:** Place the `PushableBlock` on `Plate A` (or have P2 stand on it) to keep `Bridge 2` extended so the team can cross to **Island C**.
3. **Lever-Locked Bridge 3:** Whip the `WallLever` on **Island B** to lock `Bridge 3` in place, letting the torch-bearer reach **Island D**, grab the `Torch`, and light the final `Brazier`.

---

## Level 7: The Twin-Weight Sanctum
**New Mechanic:** **Heavy Pressure Plates** — require **2 units of weight** (2 players, 1 player + 1 crate, or 2 crates) to depress, with a clear `1/2` → `2/2` rune indicator.

```text
+--------------------------------------------------+
| [Exit] <--- [AncientDoor]                        |
|                  ^                               |
|          [Heavy Plate C] (Needs 2/2)             |
|           /           \                          |
|  [Dart Hall]       [Mirror Wing]                 |
|  (Crate 2)         (SunReceiver -> opens         |
|      ^              Crate 1 gate)                |
|  [Whip Hook]            ^                        |
|      |             [Mirror 1 & 2]                |
|  [Heavy Plate A] <-- (Tutorial: 2 players or     |
|   (Needs 2/2)         1 player + 1 crate!)       |
|      ^                                           |
|   [Start]                                        |
+--------------------------------------------------+
```

### Flow
1. **Tutorial Heavy Plate A:** Placed right at the entrance with 1 `PushableBlock` nearby—stepping on it alone shows `1/2` (half-sunk), while pushing the crate onto it + standing on it (or 2 players standing on it) triggers `2/2` and opens the main hall.
2. **Mid-Level:** Combines `WhipHook`s, `DartTrap`s, and `MirrorPillar`s to free **Crate 1** and **Crate 2**.
3. **Finale:** Stack both crates onto `Heavy Plate C` (or 1 crate + 1 player in co-op) to unlock `AncientDoor` and reach `LevelExit`.
