# sRaidFrames — WoW: Forever Edition

> **中文简介：** 专为《魔兽世界：无限（WoW: Forever）》翻新打造的经典 `CT_RaidAssist` 风格小队/团队框架：拒绝冰冷色块网格，保留完整双名、圆形 2D 头像、预判治疗条、智能职业 Buff/驱散高亮与 DBM 点名警报，让你直观地与每一位有名字的队友并肩作战。

**Tired of turning your teammates into cold, flat spreadsheet blocks?**

**sRaidFrames (WoW: Forever Edition)** is a modernized continuation of the classic **sRaidFrames** addon (*Saroz, Nevcairiel, Stolenlegacy*), rebuilt by **Elunia-Moonshadow** for **World of Warcraft: Forever (1.60.1 / Interface 16001)**.

It preserves the classic **CT_RaidAssist** 3-row layout—full dual-names, circular 2D Party portraits, muted-green incoming heals, smart class-specific buffs, dispellable highlights, and DBM alerts—so it feels like fighting alongside real, named teammates.

---

## Core Highlights

* **Pure Target Selection — Zero Clutter**
  * Classic 3-row separated frames (**Name + Auras / Health / Power**); **left-click strictly targets** (`type1 = "target"`, no click-casting).
  * **Full Forever Dual-Names** always colored by class.

* **Blizzard-Style 5-Player Party Mode**
  * **Circular 2D Portraits** on the left (default race/gender fallback until in view range; auto-collapses in Raids).
  * **Authentic Corner Badges:** **Leader Crown** (top-left), **Tank / Healer / DPS Role** (bottom-right), and **Voice Speaker** (bottom-left, only while speaking).
  * Displays **`Lv.XX`** neatly stacked below the Class Icon and defaults to **Tank → DPS → Healer** sorting (customizable in `/srf`).

* **Smart Buffs, Weakened Soul & Combat-Safe Dispels**
  * **Class-Aware Raid Buffs:** Automatically shows what your class manages (e.g., *Paladins* see Blessings, *Priests* see Fortitude/Spirit/Shield/HoTs), or switch to **All-Class** anytime.
  * **Weakened Soul** always stays visible on the debuff side; **Magic / Curse / Disease / Poison** show color-coded borders and full-frame highlights via Forever's combat-safe `AuraContainer`.

* **Incoming Heals, Raid Badges & DBM Alerts**
  * **Incoming Heal Prediction** in muted green + 6 health text formats (including negative deficit).
  * **4x2 Default Raid Grid** (`1–4` top, `5–8` bottom) with **Leader Crown**, **Main Tank / Main Assist** badges, and **DBM-Core (12.1.24)** / `isBossAura` boss warnings.

---

## Customization & Extras

* **Flexible Positioning:** Drag an unlocked group title to move one group, or **`Alt + Drag`** to move all 8 groups together.
* **4K-Ready & Roomy Party Spacing:** Adjustable scale (up to `3.0x`), frame size, bar heights, and independent Party spacing, plus a one-click **Reset** for position, size, and spacing.
* **Minimap Icon & 9 Languages:** Left-click minimap icon for `/srf` settings, right-click to toggle frames; taint-free Blizzard frame hiding; supports **enUS, zhCN, zhTW, deDE, frFR, esES, esMX, koKR, ruRU**.

---

## Installation (How to Install)

1. Download and extract the `.zip` archive.
2. Place the extracted **`sRaidFrames`** folder into your **WoW: Forever** `Interface\AddOns\` directory:
   * Example: `...\World of Warcraft\_forever_\Interface\AddOns\sRaidFrames\`
3. **Important:** Avoid double-nested folders—`sRaidFrames.toc` must be directly inside `Interface\AddOns\sRaidFrames\`:
   * ✅ **Correct:** `Interface\AddOns\sRaidFrames\sRaidFrames.toc`
   * ❌ **Wrong:** `Interface\AddOns\sRaidFrames\sRaidFrames\sRaidFrames.toc`
4. Restart the game client and ensure **sRaidFrames** is enabled in the **AddOns** menu.

---

## Slash Commands

* `/srf` — Open settings (or left-click the Minimap Icon)
* `/srf lock` / `/srf unlock` — Lock or unlock frames for dragging

---

## Credits & License

* **Original Authors:** Saroz, Nevcairiel, Stolenlegacy
* **WoW: Forever Port & Modernization:** Elunia-Moonshadow
* **License:** GNU General Public License v2.0 (GPLv2)
