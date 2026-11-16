# Raiders of the Lost Temple 🏛️💎

Ett 2.5D isometriskt pussel-äventyrsspel för 1–4 spelare i samma anda som *Minecraft Dungeons* och *Raiders of the Lost Ark / Indiana Jones*. Byggt för **Godot 4.7**.

---

## 🪨 Skjut- & Dragbara Stenblock (`PushableBlock`)

Du kan flytta de forntida sandstensblocken på två smidiga sätt:
1. **Gå rakt mot blocket:** När du springer eller går mot blocket skjuter din karaktär automatiskt blocket framåt framför sig med mjuk friktion.
2. **Greppa & Dra/Skjut (`E` / Gamepad `A`):** Tryck på **E** (eller **A** på handkontroll) intill blocket för att ta tag i det. Du kan nu både **skjuta och dra (backa)** blocket med dig! Tryck på **E** igen för att släppa.
   * Placera blocken på tryckplattor för att hålla stendörrar öppna när du spelar solo, eller använd dem som sköld mot giftpilsfällor!

---

## 🎥 Kamerarotation & Inneslutna Tempelväggar

1. **🔄 360° Fri & Stegvis Kamerarotation:**
   * **Tangentbord:** Tryck **Q** för att rotera kameran 45° moturs, eller **R** (alt. **C**) för 45° medurs. Håll in för mjuk kontinuerlig rotation!
   * **Mus:** Håll **Höger Musknapp (RMB)** och dra musen åt vänster/höger för att fritt rotera kameran runt äventyrarna. Du kan även använda **Skrollhjulet** för att steg-rotera!
   * **Handkontroll (Gamepad):** 
     * **Höger Analogspak:** Mjuk steglös orbital rotation.
     * **LB / RB (Shoulder Bumpers):** Snäpprotera 45° åt vänster eller höger.
   * **Dynamisk Styrning:** Spelarens rörelserikting anpassar sig automatiskt efter kamerans aktuella vinkel – **W** går alltid uppåt på skärmen oavsett hur du roterar kameran!

2. **🧱 Fullständiga Tempelväggar & Genomskinlighet vid Skymning:**
   * Alla kammare, korridorer och sanktuarier i nivåerna är nu helt inneslutna av massiva sandstensväggar med dörröppningar.
   * **Smart Occlusion Fade:** När du roterar kameran och en vägg hamnar mellan kameran och spelarna tonas väggen automatiskt ned till halvgenomskinlig, så att du aldrig tappar sikten på din karaktär!

---

## 🗺️ Tempelkampanjen (3 Olika Nivåer)

* **🏛️ Nivå 1: Soltemplets Ruiner:** Tryckplattor, sandstensblock, giftpilar och den vilda flykten från det rullande stenblocket!
* **💀 Nivå 2: Den Mörka Katakomben:** Eldfat, spikfällor, dubbla väggspakar och jakt på Obsidian-skarabén.
* **🪞 Nivå 3: Faraos Spegelsal:** Spegelljusreflektioner mot solkristaller, 4-spelarplattor och Ras Öga.

---

## 👥 Spelarval & Startnivå (1–4 Spelare)

* Välj **1 till 4 spelare** och valfri **Startnivå** direkt i huvudmenyn.
* **Drop-in:** Tryck `Enter` eller Gamepad `A` för att hoppa in direkt i spelet.
* Tryck **ESC** när som helst under spelets gång för att återgå till menyn.

---

## 🎮 Spelkontroller

| Handling | Tangentbord | Handkontroll (Gamepad) |
| :--- | :--- | :--- |
| **Spelare 1** | **W / A / S / D** (Gå / Skjut block)<br>**E** (Greppa block / Bär / Interagera)<br>**Mellanslag** (Piska) | **Vänster Styrspak** (Gå / Skjut)<br>**A / Kryss** (Greppa / Interagera)<br>**X / Fyrkant** (Piska) |
| **Spelare 2** | **Piltangenter** (Gå)<br>**Enter** (Greppa / Interagera)<br>**Höger Skift** (Piska) | **Vänster Styrspak (Kontroll 2)**<br>**A / Kryss** (Greppa / Interagera)<br>**X / Fyrkant** (Piska) |
| **Spelare 3 & 4** | - | **Kontroll 3 & 4** (Spak + A/X) |
| **Rotera Kamera** | **Q / R** (eller håll **Höger Musknapp** och dra) | **Höger Spak** / **LB & RB** |
| **Meny** | **ESC** | **Start / Menu** |

---

## 🚀 Hur du startar i Godot 4.7

1. Öppna **Godot Engine 4.7**.
2. Öppna projektet `D:\Puzzle game`.
3. Tryck på **F5** för att starta spelet och testa att flytta stenblocket!
