# sRaidFrames (WoW: Forever Edition) — V1.1.2

**sRaidFrames (WoW: Forever Edition)** is a lightweight, modernized, combat-safe continuation of the classic *CT_RaidAssist*-style party and raid frames for **all classes and roles (Tanks, Healers, and DPS)**, engineered specifically for **World of Warcraft: Forever (`1.60.x` / Interface `16001`)** with cross-client Classic compatibility.

Built around a **Pure Target Selection** philosophy — **Left-Click to Target, Right-Click for the native Blizzard Unit Menu, zero click-casting automation** — it pairs nostalgic, high-contrast card aesthetics with Forever's native `CustomAuraContainerTemplate` engine and full Secret-Value protection for zero taint and zero combat errors.

---

## Key Features

### 1. Classic Card Aesthetics & Dual-Name Support
- **High-Contrast Sky-Blue Card Backdrop**: Classic steel/sky-blue backdrop (`{0.22, 0.35, 0.50}`) with crisp white borders and deep health/mana wells so Mage cyan and all class-colored names stand out clearly.
- **Class-Colored Unit Names**: Teammate names are always colored by class, with health bars optionally colored by class or smooth HP-severity gradient (green to red).
- **Dual-Name Display (`16001`)**: Full support for Forever's dual-name system — display **Full Name (`Character <Account>`)**, **First Name Only**, or **Second Name Only**.
- **Pure Targeting & Native Context Menu**: Left-click strictly selects the unit; right-click opens the standard Blizzard unit menu (whisper, inspect, trade, focus, promote). No click-cast spell hijacking.

### 2. Blizzard-Style 5-Player Party Mode
- **Full 5-Player Party by Default (Optional Hide Self)**: Shows all 5 party members out of the box (`Show myself in party` enabled by default), with a 1-click toggle in `/srf` if you prefer showing only your 4 teammates.
- **Vertical Stacking or Horizontal Tiling**: Switch independently between **Vertical** and **Horizontal** Party tiling (`Party layout direction`), without affecting your Raid grid layout.
- **Circular 2D Portraits**: Live circular 2D unit portraits on the left of each party card with automatic race/gender fallback icons when teammates are out of rendering range.
- **Crisp Party Typography**: Upgraded `GameFontNormal` shadowed names in 5-player Party mode for effortless readability, while keeping 40-player Raid frames compact.
- **Corner Status Badges**:
  - **Top-Left**: Raid/Party Leader gold crown.
  - **Bottom-Right**: Assigned role badge (**Tank / Healer / DPS**).
  - **Bottom-Left**: Live **Voice Chat speaker indicator** that lights up while a teammate is speaking.
- **Right-Side Info Column**: Dedicated column to the right of the health and power bars showing each teammate's **Class Icon** above their **Level (`Lv.60`)**.

### 3. 40-Player Raid Grid, Safe Dragging & Scaling
- **3 Preset Raid Formations**: Defaults to a **4x2 Compact Raid Grid** (Groups 1–4 on top, Groups 5–8 on bottom), plus **Horizontal** (1x8) and **Vertical** (2x4) presets.
- **Unified Group Sort Order**: Sort both 5-player Party and By-Group Raid frames by **Tank -> DPS -> Healer (Default)**, **Tank -> Healer -> DPS**, **Blizzard Default**, or **Alphabetical (A–Z)**, while preserving per-group custom sort overrides.
- **Locked by Default & Free Dragging**: Frames default to **Locked** to prevent accidental dragging in combat. Unlock in `/srf` to drag any group by its title bar **or directly by any unit frame**, hold **Alt + Drag** to move all groups and the pet group together, adjust **Overall frame scale** (`0.5`–`2.0`) in *Layout & Positioning*, or click **Reset position**.
- **Combat-Safe Blizzard Frame Hiding & Edit Mode Friendly**: Safely hides Blizzard's default Party and Compact Raid Frames without combat taint, and yields cleanly whenever Blizzard's UI Edit Mode is opened.

### 4. Three-Mode Pet Health Bar System (`/srf` -> Pets)
Configure pet display independently for **5-Player Party** and **Raid**:
- **Follow Teammate Frame**:
  - **5-Player Party**: Reserves uniform combat-safe spacing below every teammate (supporting mid-combat pet summons and Mind Control) with a compact right-aligned `48%` pet sub-bar and circular 2D pet portrait.
  - **Raid**: Tucks a sleek gold-bordered mini pet bar into the bottom-right of the owner's power bar row with zero extra frame height.
- **Separate Pet Group**: Creates a standalone, draggable **Pets** group (`SecureGroupPetHeaderTemplate`) with owner-class colored pet names, native pet tooltips, instant mid-combat summon updates, and saved positioning.
- **Pet Heal Prediction & Micro Auras**: Supports incoming heal prediction, left-click targeting, right-click pet menu, target highlight, range fade, and `9x9` low-pixel HoT / Shield / Dispel icons in the top-right corner of pet health bars *(Party Follow & Separate Pet Group modes)*.

### 5. Combat-Safe Auras, Dispel Highlighting & Boss Warnings
- **Native Forever Aura Containers**: Powered by Blizzard's `CustomAuraContainerTemplate` and `ScopedModifier` to display top-right Buffs (rightmost) and Debuffs (chained to the left) during combat lockdown without Secret-Value errors.
- **Smart Class & Raid Buff Filtering**:
  - **Smart Class Mode (Default)**: Automatically filters long raid buffs to match your class (e.g., Fortitude/Spirit for Priests, Blessings for Paladins, Mark of the Wild/Thorns for Druids, Arcane Intellect for Mages, Unending Breath/Detect Invisibility for Warlocks).
  - Also supports **All Class Raid & Combat Buffs**, **Combat & Healing Buffs Only**, or **My Buffs Only**.
- **HoTs, Shields, Defensive Cooldowns & Dispel Highlighting**: Prioritizes key HoTs, shields, Weakened Soul, and defensive cooldowns across classes; features color-coded debuff borders and combat-safe unit background tinting for Magic, Disease, Poison, and Curse effects.
- **Boss & DBM / BigWigs Alerts**: Highlights teammates targeted by Boss casts or DBM / BigWigs announcements with a high-priority flame border, `! BOSS SKILL !` status text, and right-side alert icon (includes a **Test Boss/DBM warning** button in `/srf`).

### 6. Healing & Raid Awareness Tools
- **Incoming Heal Prediction Bar**: Clipped pale-green heal prediction bar extending from current health (supports both standard and inverted health bars).
- **6 Health Display Formats**: Percent, Deficit, Current, Current + Max, Current + Deficit (with % in combat), or None — plus optional **Hide health text at 100% HP**.
- **Aggro, Range, Ready Check & Resurrection**:
  - Red border highlight on teammates holding aggro (`UnitThreatSituation`).
  - Smooth out-of-range alpha fading (`RangeCheck`) using class-appropriate spell ranges.
  - Ready Check background status highlights (Pending / Ready / Not Ready).
  - Hardened `LibResInfo-1.0` resurrection tracking (Casting Res, Pending Accept, Soulstone, and Hunter Feign Death exclusion).

---

## Commands & Shortcuts
- **`/srf`**: Open the configuration panel (organized into 8 clean categories and localized in 9 languages: `enUS`, `zhCN`, `zhTW`, `deDE`, `esES`, `esMX`, `frFR`, `koKR`, `ruRU`).
- **Minimap Button**: **Left-Click** to open settings; **Right-Click** to show/hide frames.
- **Keybindings**: Bind keys under *Options -> Keybindings -> sRaidFrames* to toggle frame visibility, cycle Buff/Debuff view (`Both -> Debuffs -> Buffs`), or toggle curable-only debuffs.

---

## Installation
1. Download and extract the `.zip` archive.
2. Place the `sRaidFrames` folder directly into your client's AddOns directory:
   - **WoW: Forever**: `World of Warcraft\_forever_\Interface\AddOns\sRaidFrames\`
   - Ensure there is no nested folder (`sRaidFrames.toc` must sit directly inside `Interface\AddOns\sRaidFrames\`).
3. Restart the game or type `/reload`, then type `/srf` to configure.

---

## Credits & License
- **Original Authors**: Saroz, Nevcairiel, Stolenlegacy
- **WoW: Forever Port & Modernization**: Elunia-Moonshadow
- **Embedded Libraries**: Ace3, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets, LibDataBroker-1.1, LibDBIcon-1.0, LibResInfo-1.0
- **License**: GNU General Public License v2.0 (**GPLv2**) — see `LICENSE.txt`
