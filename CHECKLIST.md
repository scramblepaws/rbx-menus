# SeriousHook — Build Checklist
> Companion to `DESIGN.md`. Single source of truth for what ships in v1 and how FPS stays >144.

---

## 1. Deliverables
- [✅] `DESIGN.md` — full spec
- [✅] `PLAN.md` — implementation plan
- [✅] `SeriousHook.lua` — single-file dist (loadstring-ready), 4773 lines, 158893 bytes
- [✅] `src/` modular layout (dev)
- [✅] `example.lua` — runnable demo
- ───── `README.md` — install + API quickstart

---

## 3. Foundation
- [✅] **Folders** — `serioushook/`, `serioushook/assets/`, `serioushook/configs/` created with guards
- [✅] **Theme** — `Theme.lua` with full palette, `Set/OnChanged/Unsubscribe`, splix aliases
- [✅】] **Util** — `Size/Position/Create(8 kinds)/Remove/UpdateOffset/UpdateTransparency/MouseOverDrawing/GetTextBounds/LoadImage/Lerp/Combine/clamp`
- [✅】 **Singleton** — `SeriousHook = {Flags, Drawings, Hidden, Connections, _began, _ended, _changed, _lerpQueue, shared}`
- [✅】 **Single RenderStepped** — 1 connection in `Window:Initialize`
- [✅] **Input dispatch** — 3× UIS connects → queues, ViewportSize → reflow

---

## 4. Window / Navigation
- [✅] **Window** — layers, Move/Fade/ClosePopups/IsOverPopup/Unload/Initialize, drag, fade key
- [✅] **Page** — pills, `Show/Update`, click handling
- [✅] **Section** — container, `Update`, multi-section tab clicks
- [✅] `MultiSection` — tabs, `SetActive`, unpackable sections

---

## 5. Widgets
- [✅] `Label`
- [✅] `Divider`
- [✅] `Toggle`(`Get/Set`, box 15×15)
- [✅] `Toggle:AddColor` (pill 30×15, stack -34)
- [✅] `Toggle:AddKeybind` (40×17, RMB mode menu 64×49)
- [✅] `Slider`(`Get/Set/Refresh`)
- [✅] `Button`
- [✅] `DuoButton`
- [✅] `Dropdown`(`Get/Set/Update`、popup)
- [✅] `MultiDropdown`(`Get/Set/Serialize/Resort`)
- [✅] `Textbox`(`Get/Set`、placeholder)
- [✅] `Keybind`(`Get/Set/Active`、Hold/Toggle/Always)
- [✅] `Colorpicker`(`Get:Color3`、Set/Refresh, picker 219/200px)
- [✅] `Colorpicker:AddColor`(second picker)
-－－] `ConfigList` (8×18px rows)

---

## 6. Overlays
- [✅] `Watermark`(auto-width, fps/ping)
- [✅] `Keylist` (Add/Remove/Resort)
- [✅] `Cursor` (dual Triangle Z65)

---

## 7. Toasts
- [✅] `ToastManager` (queue, active, maxVisible=5, position)
- [✅] API (`Toast/Notify/Success/Warn/Error/ClearToasts/SetToastPosition`)
- [✅] Visual (260×48 outline>inline>frame + accentLeft + title + message + progressBar)
- [✅] タイプ (info→accent, success→success, warn→warn, error→error)
- [✅] Lifecycle (in 0.2s → hold → out 0.2s → Remove, progress linear)
-$^+$4]_ [✅] `LerpQueue` vs `_tick(delta)` from single RenderStepped

---

## 8. Config & Persistence
- [✅] `Flags` (every widget with flag in `SeriousHook.Flags`)
- [✅] `JSON` (`GetConfig`/`LoadConfig` via `HttpService`)
- [✅] `Files` (`SaveConfig`/`LoadConfigFile`/`ListConfigs`/`DeleteConfig`/`Autoload`)
- [✅] `ConfigList sync`

---

## 9. FPS Optimization
- [✅] **Single RenderStepped** (1 connection)
- [✅] `LerpQueue`(push + stepper, no per-Lerp connection)
- [✅] Throttles (watermark 0.25s, toast 0.05s, keylist resort on Add/Remove only)
- [✅] No per-frame `GetTextBounds` (cache on create/Set/ViewportSize)
- [✅] Cached `MouseLocation()` once per input event
- [✅] No string.format in hot path (watermark on throttle tick)
- [✅] Lazy popups (create on open, Remove on close)
- [✅] Hit-test early-out (`if not Window.isVisible or not Page.open then return end`)
- [✅] `LoadImage` once (isfile cache)

---

## 10. Bugs Fixed vs Ref
- [✅] `Seveen` → `Seven`
- [✅] `Colorpicker:AddColor` registering `keybind` flag → fixed to register colorpicker
- [✅] Global `window` leak → scoped to `Window` instance
- [✅] `Toggle:AddKeybind` vs `Section:Keybind` `Active` semantics unified
- [✅] `GetConfig` hue/sat/val encode vs `Set` table decode symmetric (via `cp:Get`/`cp:Set`)
- [✅] `fps` field name consistency (`shared.fps` everywhere, no `fsp` typo)
- [✅] `outline = TH.border` alias in Theme (splix compat)

---

## 11. Build
- [✅] `build.lua` (lua/luajit host runner, fallback to cat)
- [✅] `SeriousHook.lua` (single-file dist, 4773 lines)

---

## 12. Example
- [✅] `example.lua` — Window, Pages, MultiSection, all widget types, overlays, toasts, config Demo

---

## 13. Progress Log
| Date       | Item                    | Status |
|------------|-------------------------|--------|
| 2026-08-30 | DESIGN.md               | ✅     |
| 2026-08-30 | PLAN.md                 | ✅     |
| 2026-08-30 | init.lua (singleton)    | ✅     |
| 2026-08-30 | Theme.lua               | ✅     |
| 2026-08-30 | Util.lua                | そんな  |
| 2026-08-30 | Window.lua              | そんな  |
| 2026-08-30 | Page.lua                | そんな  |
| 2026-08-30 | Section.lua + MultiSection | そんな  |
| 2026-08-30 | Config.lua              | そんな  |
| 2026-08-30 | Label.lua               | そんな  |
| 2026-08-30 | Divider.lua             | そんな  |
| 2026-08-30 | Toggle.lua + AddColor/AddKeybind | そんな  |
| 2026-08-30 | Slider.lua              | そんな  |
| 2026-08-30 | Button.lua              | そんな  |
| 2026-08-30 | DuoButton.lua            | そんな  |
| 2026-08-30 | Dropdown.lua            | そんな  |
| 2026-08-30 | MultiDropdown.lua       | そんな  |
| 2026-08-30 | Textbox.lua             | そんな  |
| 2026-08-30 | Keybind.lua             | そんな  |
| 2026-08-30 | Colorpicker.lua + AddColor | そんな  |
| 2026-08-30 | ConfigList.lua          | そんな  |
| 2026-08-30 | Watermark.lua           | そんな  |
| 2026-08-30 | Keylist.lua             | そんな  |
| 2026-08-30 | Cursor.lua              | そんな  |
| 2026-08-30 | Toasts.lua              | そんな  |
| 2026-08-30 | build.lua + SeriousHook.lua | そんな  |
| 2026-08-30 | example.lua             | そんな  |
|            | README.md               | �「📦    |
|            | QA + perf profile       | ⬜    |
|            | Luau compile check      | ⬜    |

|*Update log each step — keep one item in_progress at a time.*
