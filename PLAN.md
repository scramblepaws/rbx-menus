# SeriousHook Implementation Plan

## Goal
Build a full, optimized Luau menu library (`SeriousHook`) with toasts, widgets, and menu navigation, structured as modular `src/` files (dev) plus a single-file dist (`SeriousHook.lua`) for loadstring use — simple enough to script-add modules.

## Reference & Specs
- `_Reference/Splix Lib Source.lua` (4032-line retained-mode Drawing lib) — proven patterns to carry over.
- `DESIGN.md` — full spec: theme, architecture, widget catalog, toast system, optimization budgets.
- `CHECKLIST.md` — build checklist and QA matrix.

## Architecture (retained, immediate-style)
- Singleton `SeriousHook` owns `Theme`, `Flags`, `Drawings[]`, `Hidden[]`, `Connections[]`, input queues (`_began/_ended/_changed`), `shared = {initialized, fps, ping}`.
- Hierarchy: `Window → Page(s) → Section/MultiSection → Widgets`. Single `RunService.RenderStepped` drives cursor, lerp queue, toast progress, watermark throttle.
- Widgets and overlays are modular files that extend `Section`/`Window` prototypes, so adding a module is: drop a file in `src/widgets/` or `src/overlays/` and require it.

## Module layout (`src/`)
- `init.lua` — public entry, requires core + auto-registers widget/overlays modules, returns `SeriousHook`.
- `Theme.lua` — theme table + `Theme:Set(key, Color3)` live update + `Theme:OnChanged`.
- `Util.lua` — `Create` (8 Drawing kinds), `Size/Position`, `Remove/UpdateOffset/UpdateTransparency`, `MouseOverDrawing`, `GetTextBounds`, `LoadImage`, `Lerp` (pushes to queue), `Combine`.
- `Window.lua` — `SeriousHook:Window(opts)` with layers, `Move/Fade/ClosePopups/IsOverPopup/Unload/Initialize`, drag, fade key, overlays host.
- `Page.lua` — `Window:Page(opts)` pills, `Show/Update`, section offset tracking.
- `Section.lua` — `Page:Section(opts)` container + title, `currentY` axis, `Update/Reflow`, plus `MultiSection` support and widget anchor helpers.
- `widgets/` — each widget file returns a function that patches `Section` (or `Page`) prototype: `Label`, `Divider`, `Toggle` (with `AddColor`/`AddKeybind`), `Slider`, `Button`, `DuoButton`, `Dropdown`, `MultiDropdown`, `Textbox`, `Keybind`, `Colorpicker` (with `AddColor`), `ConfigList`.
- `overlays/` — `Watermark`, `Keylist`, `Cursor`.
- `toasts.lua` — `ToastManager` + `SeriousHook:Toast/Notify/Success/Warn/Error/ClearToasts/SetToastPosition`, animated lifecycle driven by single RenderStepped.
- `config.lua` — `Flags` contract, `GetConfig/LoadConfig/SaveConfig/LoadConfigFile/ListConfigs/DeleteConfig/Autoload`.

## Optimization contract (from DESIGN §13)
- Exactly 1 `RenderStepped` connection in `Window:Initialize` (plus lerp queue stepper if split — total ≤2).
- `Lerp` pushes to a queue; stepper interpolates and disconnects on done — no per-Lerp connection.
- Throttles: watermark fps/ping every 0.25s, toast progress every 0.05s, keylist resort only on add/remove.
- No per-frame `GetTextBounds` — cache on create / `Set(text)` / viewport change.
- `MouseLocation()` cached once per input event.
- Lazy popups (dropdown/colorpicker/toast) created on open, removed on close; toast cap 5.
- Hit-test early-out before `MouseOverDrawing`.
- `LoadImage` cached via `isfile`.
- Config JSON iterates `Flags` only.

## Build & distribution
- Dev: `src/init.lua` loads modules via relative requires (Roblox executor `require` may not work; alternative: manual concatenation). Provide `build.lua` that reads `src/*.lua` + `src/**/*.lua` in order and writes `SeriousHook.lua`.
- Dist: `SeriousHook.lua` is loadstring-ready single file.

## Extensibility (script-together modules)
- Each widget file exposes `Section:WidgetName` (or `Page:WidgetName`) by closing over `Section` prototype; new modules follow same shape and are auto-picked up by `init.lua` if listed in a manifest, or manually required.
- New overlays: add file to `overlays/` that attaches to `Window` prototype; `Window:Initialize` calls registered overlay initializers.

## Order of implementation
1. Theme + Util (foundation).
2. Window + Page + Section + MultiSection (navigation/core).
3. Widgets: Label, Divider, Toggle, Slider, Button, DuoButton, Dropdown, MultiDropdown.
4. Pickers/Keybinds: Colorpicker (+AddColor), Keybind, Toggle:AddKeybind.
5. Overlays: Watermark, Keylist, Cursor, ConfigList.
6. Toasts + Textbox + Divider + LerpQueue + perf pass.
7. Config persistence + example.lua + build.lua + README.
8. QA against CHECKLIST.md (resolution reflow, fade, dropdowns, keybinds, toast spam, config round-trip, unload leak, perf).

## Decisions (per DESIGN §16, adopted)
- Size/accent: new `540×620`, violet `105,90,255`.
- Toast anchor: `bottomRight` default.
- Textbox: included in v1.
- Single-file dist + `src/` modules: both.
- Fade key: `RightShift`.
