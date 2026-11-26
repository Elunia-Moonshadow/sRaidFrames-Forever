# sRaidFrames (WoW: Forever Edition) Changelog

## V1.1.2 (2026-11-26)
- **Combat-Safe Blizzard Frame Hiding**: Replaced `RegisterStateDriver` / `Hide()` calls on Blizzard's EditMode-managed `PartyFrame` and `CompactRaidFrameContainer` in `HideBlizzard()` with out-of-combat hidden-parent reparenting (`sRaidFramesHiddenBlizzParent`), eliminating `ADDON_ACTION_FORBIDDEN` errors during `GROUP_ROSTER_UPDATE` (`UpdateRoster`).
- **Pet Tooltip Fix**: Updated CTRA-style raid tooltips (`UnitTooltip`) to detect pet units (`raidpet*`) via `IsPetUnit()` and fall back to Blizzard's native `GameTooltip:SetUnit()` instead of reading owner metadata via `GetRaidRosterInfo(frame.id)`.
- **Out-of-the-Box Defaults**: Changed default settings to `Locked = true` (preventing accidental frame dragging in combat) and `ShowSelfInParty = true` (showing all 5 party members by default).
- **All-Class Option & Locale Clarity**: Updated `/srf` aura option labels, TOC notes, and all 9 language locales (`enUS`, `zhCN`, `zhTW`, `deDE`, `esES`, `esMX`, `frFR`, `koKR`, `ruRU`) to clearly reflect all-class & healing buff support instead of Priest-only wording.

## V1.1.1 (2026-11-25)
- **Refined Card Contrast**: Tuned the default sky-blue card backdrop (`{0.22, 0.35, 0.50, 0.92}`) to preserve the classic CTRA look while giving Mage and other light class-colored names sharper readability.
- **Instant Unit & Group-Join Sync**: Expanded immediate `UpdateAll` refresh to all newly assigned party/raid frames upon `unit` attribute binding, with non-empty name fallback protection.
- **16001 Client Event & Blizzard Frame Integration**: Added `C_EventUtils.IsEventValid` filtering for modern client events and switched Blizzard frame hiding (`PartyFrame` / `CompactRaidFrameContainer`) to safe `RegisterStateDriver` visibility control.

## V1.1.0 (2026-11-24)
- **Party Enhancements & Typography**: Upgraded 5-player Party names to `GameFontNormal` with crisp drop shadow; Party mode defaults to showing your 4 teammates (excluding yourself) with a toggle to include yourself (5 frames), and adds horizontal tiling (`Party layout direction`) alongside vertical stacking.
- **Pet Health Bar System (`/srf` -> Pets)**: Independent Party & Raid modes (*Follow teammate frame*, *Separate pet group*, or *Do not show*), featuring 2D pet portraits, incoming heal prediction, range fade, and `9x9` top-right HoT/Shield/Dispel icons (Party Follow & Separate Pet Group modes).
- **Enhanced Interaction & Health Display**: Added native right-click unit context menu alongside pure left-click targeting, direct unit-frame free dragging when unlocked, quick overall frame scaling in Layout & Positioning, plus unified reverse-fill health bars and clipped incoming heal prediction.
- **Streamlined `/srf` Options & Aura Controls**: Reorganized settings into 8 clean categories, added 3-way keybind cycling for Buff/Debuff visibility, unified Priest & class raid buff filtering, and tailored option visibility for native `16001` aura containers.
- **9-Language Polish & Lean Footprint**: Refined all 9 language translations (`enUS`, `zhCN`, `zhTW`, `deDE`, `esES`, `esMX`, `frFR`, `koKR`, `ruRU`) and streamlined embedded libraries for lower memory and CPU overhead.

## V1.0.3
- Added Blizzard-style Party layout with circular 2D portraits, Leader/Role/Voice badges, Class Icon + Level column, uniform sorting (`Tank -> DPS -> Healer`), 4x2 Raid grid, Incoming Heal Prediction bar, Smart class-specific raid buff filtering, Minimap icon, and official Forever `AceGUI-3.0 (v41)` compatibility.

## V1.0.0 - V1.0.2
- Ported classic `sRaidFrames` to World of Warcraft: Forever (`1.60.x` / Interface `16001`) with secret-value safe guards, `CustomAuraContainerTemplate` support, DBM/BigWigs alerts, and dual-name display.
