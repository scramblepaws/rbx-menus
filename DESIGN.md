# SeriousHook — Menu Library Design Sheet

> **Version:** 1.0-draft | **Date:** 2026-08-30 | **Reference:** `_Reference/Splix Lib Source.lua` (4032 lines)
> **Author:** SeriousHook Team | **Target:** Roblox executors (Synapse / Script-Ware style `Drawing` API + `isfile/makefolder/writefile`)

---

## 0. Overview

SeriousHook is a **Drawing-based immediate-mode-retained** menu library. It is a spiritual successor to Splix — keeping the proven `Window → Page → Section → Widget` hierarchy and `utility:Create` Drawing abstraction — but with unified naming (`SeriousHook.Flags` not `pointers`), a modern violet brand, first-class **Toasts**, missing widgets (`Textbox`, `Divider`), and an **FPS-first** architecture (single RenderStepped, throttled overlays, pooled Drawings).

**Single-file dist:** `SeriousHook.lua` (loadstring-ready). **Modular src:** `src/` for development (built via cat).

---

## 1. Brand & Naming

| Concept | Splix name | SeriousHook name | Rationale |
|---|---|---|---|
| Singleton | `library` | `SeriousHook` | Brand |
| Config registry | `library.pointers` | `SeriousHook.Flags` | Ecosystem standard (Linoria/Rayfield) |
| Alias | `pointer/flag` both | `flag` canonical, `pointer` alias | Back-compat |
| Window ctor | `library:New` | `SeriousHook:Window(opts)` | Explicit |
| Page ctor | `library:Page` | `Window:Page(opts)` | Scoped |
| Section ctor | `pages:Section` | `Page:Section(opts)` |  |
| Multi-section | `pages:MultiSection` | `Page:MultiSection(opts)` |  |
| Dual buttons | `sections:ButtonHolder` | `Section:DuoButton(opts)` | Clear |
| Multi-select | `sections:Multibox` | `Section:MultiDropdown(opts)` | Consistent |
| Config slots | `sections:ConfigBox` | `Section:ConfigList()` |  |
| Folders | `splix/*` | `serioushook/*` | Brand |

**Folders:** `serioushook/`, `serioushook/assets/`, `serioushook/configs/`, `serioushook/toasts/` (optional log).

---

## 2. File Layout

```
SeriousHook/
  DESIGN.md
  CHECKLIST.md
  SeriousHook.lua              # built single-file dist
  src/
    init.lua                   # public require
    Theme.lua
    Util.lua
    Config.lua
    Window.lua
    Page.lua
    Section.lua
    widgets/
      Label.lua
      Divider.lua
      Toggle.lua
      Slider.lua
      Button.lua
      Dropdown.lua
      MultiDropdown.lua
      Keybind.lua
      Colorpicker.lua
      Textbox.lua
      ConfigList.lua
    overlays/
      Watermark.lua
      Keylist.lua
      Cursor.lua
      Toast.lua
  _Reference/
    Splix Lib Source.lua
```

---

## 3. Theme

```lua
Theme = {
  accent      = Color3.fromRGB(105,  90, 255), -- SeriousHook violet
  surface0    = Color3.fromRGB(20,  20,  22),  -- dark_contrast (ref:50)
  surface1    = Color3.fromRGB(28,  28,  30),  -- light_contrast
  surface2    = Color3.fromRGB(36,  36,  38),
  border      = Color3.fromRGB(0,    0,   0),  -- outline
  borderMuted = Color3.fromRGB(50,  50,  52),  -- inline
  text        = Color3.fromRGB(255,255,255),  -- textcolor
  textDim     = Color3.fromRGB(180,180,180),
  textOutline  = Color3.fromRGB(0,  0,   0),   -- textborder
  success     = Color3.fromRGB(70, 200,120),
  warn        = Color3.fromRGB(255,180,  0),
  error       = Color3.fromRGB(255, 70, 70),
  cursorOuter = Color3.fromRGB(10,  10,  10),  -- cursoroutline
  font        = 2,    -- Drawing.Font.Monospace
  textsize    = 13,
}
-- API: Theme:Set(key, Color3) live-updates all Drawings via registry
--      Theme:OnChanged(callback)
```

**Assets (cached to `serioushook/assets/` via `Util:LoadImage`):**
`gradient 5hmlrjX.png`, `arrow_down tVqy0nL.png`, `arrow_up SL9cbQp.png`, `valsat wpDRqVH.png`, `hue iEOsHFv.png`, `transp ncssKbH.png`, `cptransp IIPee2A.png`, `cursor mvonwalk/...cursor.png`, `toast_*` icons (new).

---

## 4. Core Architecture

```
SeriousHook (singleton)
 ├─ Theme, Flags, Drawings[], Hidden[], Connections[]
 ├─ Queues: _began[], _ended[], _changed[]
 ├─ shared {initialized, fps, ping}
 ├─ Window ─┬─ pages[] ─┬─ sections[] ─┬─ widgets (currentY axis)
 │          │           │              └─ visibleContent[]
 │          │           └─ MultiSection {tabs[], current, backup}
 │          └─ currentPopup {dropdown|multiDropdown|colorpicker|keybind}
 │          └─ overlays {watermark, keylist, cursor}
 └─ ToastManager {queue[], active[], maxVisible=5}
```

**Execution model (retained):** `Util:Create` allocates `Drawing` objects once, stores in `Drawings` with `{instance, offset, alpha}`. `Window:Move(pos)` repositions via `Util:Position` offsets. Input via 3 centralized `UserInputService` connects dispatching to `_began/_ended/_changed` queues. Render via **single** `RunService.RenderStepped` (see §9 Optimization).

---

## 5. Utility Layer (`Util`) — keep ref behavior verbatim

- **`Util:Create(kind, offset, props, parentList?)`** — `kind` in `Frame/TextLabel/Triangle/Image/Circle/Quad/Line` (ref:96). Defaults `ZIndex 50`, `Transparency = initialized and 1 or 0`. Iterates `props`; if key `Hidden` push to `Hidden` else `Drawings`. Returns `Drawing`.
- **`Util:Remove(draw, hidden?)`**, **`UpdateOffset(draw, off)`**, **`UpdateTransparency(draw, a)`** — maintain registry.
- **`Util:Size/Position`** — viewport-relative math (ref:64,80).
- **`Util:MouseOverDrawing({x1,y1,x2,y2})`**, **`GetTextBounds(text,size,font)`** — hidden-label trick (ref:292).
- **`Util:LoadImage(draw, name, url)`** — `isfile`→`readfile` else `HttpGet`→`writefile` (ref:312).
- **`Util:Lerp(inst, to, time)`** — queued lerp via RenderStepped (ref:331) — **replaced by single LerpQueue (see §9)**.
- **`Util:Combine(t1,t2)`** — array concat.

---

## 6. Window / Page / Section Spec

### 6.1 `SeriousHook:Window(opts)`

```lua
Window = SeriousHook:Window{
  title    = "SeriousHook | v1.0",
  size     = Vector2.new(540, 620), -- ref was 504x604 (ref:373)
  accent   = Color3.fromRGB(105,90,255),
  fadeKey  = Enum.KeyCode.RightShift, -- was Enum.KeyCode.Z (ref:378)
  draggable= true,
}
```

**Drawing layers (inside-out, ref:380-441):**
`main(border) > accent(1px top, Theme.accent) > outer(surface1) > innerBorder(borderMuted) > outline2(border) > tabHost(surface0)` + `title TextLabel at 4,2`.

**Tab bar:** `Frame {4,24} size 1,-8 x 1,-28` of `tabHost` hosts Pages.

**Methods:**
- `Window:Move(Vector2)` — clamp `x in [5, ViewportSize.X - size.X -5]` (ref:975), iterate `Drawings` re-`Position`.
- `Window:Fade()` — toggle `isVisible`, lerp all `Drawings.Transparency` `0↔stored` over `0.25s`, toggle `cursor + MouseIconEnabled` (ref:922).
- `Window:ClosePopups()` — closes whichever of `dropdown/multiDropdown/colorpicker/keybind` is open (ref:478).
- `Window:IsOverPopup()` — hit-test `currentPopup.frame` (ref:538).
- `Window:Unload()` — disconnect `Connections`, `:Remove()` all Drawings (ref:548).
- `Window:GetConfig() → json`, `LoadConfig(json)`, `SaveConfig(name)`, `LoadConfigFile(name)`.
- `Window:Initialize()` — `pages[1]:Show()`, `Watermark/Keylist/Cursor` init, `Fade()` in, `shared.initialized=true` (ref:939).

**Input & viewport:** `InputBegan/Ended/Changed` + `CurrentCamera:GetPropertyChangedSignal("ViewportSize") → Move(center)` (ref:1002-1032).

### 6.2 `Window:Page(opts)` — `Page = Window:Page{name="Aimbot", icon="..."}`

Pill width `GetTextBounds(name).X + 20`, x=`4 + Σ(prev.W+2)`, h=`21`, layers `outline(border)>muted(borderMuted)>color(surface0/surface1)`. `color = open and surface1 or surface0`. `Page:Show()` hides `currentPage.sections[].visibleContent`, calls `ClosePopups`, shows own sections.

### 6.3 `Page:Section(opts)` — `Section = Page:Section{name="Main", side="left"|"right"}`

Container `inline(borderMuted) > outline(border) > frame(surface0) > accent(2px top)` + title. `Size = 0.5,-7 x currentY+4`, `Position = side=="right" and (tabHost.W/2+2, 5+offset) or (5, 5+offset)` (ref:1140). `currentY` starts `20`, each widget does `currentY += h+4`, `Section:Update()` resizes containers, `Page:Reflow()` recomputes `sectionOffset[left/right]`.

### 6.4 `Page:MultiSection(opts)` — `local A,B = Page:MultiSection{tabs={"Main","Settings"}, side="left", height=180}`

Header `backFrame(surface1, h17) + bottomLine(border) + accent(2px)`. Tabs `GetTextBounds(v).X+14` wide, active `surface0` else `surface1`. Creates N pseudo-sections sharing host; `SetActive(tab)` swaps `visibleContent = Combine(backup, active.visibleContent)`. Returns `unpack(sections)` for destructuring (ref:1325).

---

## 7. Widget Catalog

> All widgets: `info` accepts `name/Name/title/Title` alias, `pointer/Pointer/flag/Flag`, `callback/callBack/Callback`. All push to `section.visibleContent`, register `Flags[flag]`, bump `currentY`, call `Section:Update()`.

| Widget | opts | h | Methods | Visual / Behavior |
|---|---|---|---|---|
| **Label** | `{name, centered=false}` | `TextBounds.Y+4` | `Set(text)` | TextLabel at `4,axis` or centered |
| **Divider** | `{text?, color?}` *(new)* | `8` | — | `--- text ---` 1px line |
| **Toggle** | `{name, default=false, flag, callback(bool)}` | `15+4` | `Get():bool, Set(bool)` | Box `15×15 outline>muted>frame` at `4,axis`, `accent` when on, hitbox `frame.X .. frame.X+W - addedAxis` (ref:1428) |
| **Toggle:AddColor** | `{name, default=Color3, alpha=0-1?, flag, callback(Color3,alpha)}` chain | inline | `Get():{Color,Alpha}, Set(Color3\|{h,s,v,a})` | Pill `30×15 outline>muted>frame` at `frame.W-(30+4)`, stacking `-34` per extra, dual offset `-(60+8)` (ref:3467) |
| **Toggle:AddKeybind** | `{default=Enum.KeyCode, mode="Always"/"Toggle"/"Hold", keyName?, flag, callback(key,active)}` | inline | `Get, Set, Active, Reset` | `40×17` pill, LMB bind, RMB mode menu `64×49 Always/Toggle/Hold` (ref:2014) |
| **Slider** | `{name, min,max,default,suffix="", decimals=1, flag, callback(val)}` | `27+4` | `Get, Set, Refresh` | Track `1,-8×12 outline>muted>frame + fill(accent)` + centered `val/suffix/max` |
| **Button** | `{name, flag, callback}` | `20+4` | — | Full-width `1,-8×20` |
| **DuoButton** | `{buttons={{name,cb},{name,cb}}}` | `20+4` | — | 2× `0.5,-6` (ref:ButtonHolder) |
| **Dropdown** | `{name, options={}, default=options[1], flag, callback(val)}` | `35+4` | `Get, Set, Update` | `20px` box + arrow, popup `3+19*#options` rows (ref:2460) |
| **MultiDropdown** | `{name, options={}, default={}, min=0, flag, callback(tbl)}` | `35+4` | `Get, Set, Serialize, Resort` | Chip text `Serialize(Resort)` (ref:2644) |
| **Textbox** | `{name, default="", placeholder, numeric=false, maxLen?, flag, callback(text)}` *(new)* | `15+4` | `Get, Set` | `outline>muted>frame` + TextLabel, captures `TextInput` |
| **Keybind** *(standalone)* | `{name, default, mode, keyName, flag, callback}` | `17+4` | `Get, Set, Active` | Same as Toggle:AddKeybind but label left |
| **Colorpicker** *(standalone)* | `{name, default, alpha?, flag, callback}` | `15+4` | `Get:Color3, Set, Refresh` | Same picker UI `219/200px` with `picker(sat/val)+hue(15px)+alpha(15px)` (ref:3224) |
| **Colorpicker:AddColor** | second picker chain | inline | — | Dual `30+4` offset |
| **ConfigList** | `Section:ConfigList()` | `148+4` | `Get():1..8, Set(n), Refresh` | 8 rows `18px` (ref:3871) |

**Colorpicker popup detail (reused for Toggle:AddColor & standalone):**
`outline>inline>frame+accent 2px` at `4,axis+19` size `1,-8 × (transp and 219 or 200)`, `picker outline 1,-27 × 1,transp and -40 or -21` at `4,17` with `valsat.png`, hue `15px` at `1,-19` with `hue.png`, optional transp bar `1,-27×15` at `4,1,-19`. Cursors `6×6`.

**Fixed ref bugs:** `Seveen→Seven` (ref:1843), `Colorpicker:AddColor` registering `keybind` flag (ref:3825) fixed, `Toggle:AddKeybind` vs `Section:Keybind` `Active` semantics unified.

---

## 8. Overlays

### 8.1 Watermark — `Window:Watermark{enabled=false, template="SeriousHook | {fps} fps | {ping} ms"}`

`outline>inline>frame+accent 1px` at `100,19` (ref:609), auto-width `TextBounds+20`, `RenderStepped` computes `shared.fps=1/delta`, `shared.ping=Stats.Network...Data Ping` throttled `0.25s` (see §9). Visibility toggles with `Window:Fade`.

### 8.2 Keylist — `Window:Keylist{enabled=false, position=Vector2(10, 0.4*H)}`

At `10, 0.4*ViewportSize.Y` size `150×22 + 18*count` (ref:702), `Add(name,keyText)/Remove/Resort/Visibility`.

### 8.3 Cursor — `Window:Cursor{enabled=true}`

Two `Triangle` at `Z 65` following `GetMouseLocation()` (ref:908), `MouseIconEnabled=false` when visible.

---

## 9. Toast System *(NEW — no ref)*

### 9.1 API

```lua
local id = SeriousHook:Toast{
  title    = "SeriousHook",
  message  = "Config loaded",
  type     = "info",      -- "info"|"success"|"warn"|"error"
  duration = 3,           -- seconds, 0 = sticky
  position = nil,         -- override global anchor
}
SeriousHook:Notify("Hello")            -- alias info
SeriousHook:Success("Saved!", 2)
SeriousHook:Warn("Low health", 3)
SeriousHook:Error("Failed", 4)
SeriousHook:ClearToasts()
SeriousHook:SetToastPosition("bottomRight") -- "topRight"|"bottomRight"|"topCenter"|"bottomLeft"
```

### 9.2 Visual

Anchor `bottomRight` default `ViewportSize - (280+12), 60 + stack*56`. Each toast `260×48`:
`outline(border) > inline(borderMuted) > frame(surface0) > accentLeft(3px, type color) + title 13px + message 12px dim + progressBar 2px bottom` + optional icon `12×12`.

| type | accent |
|---|---|
| info | `Theme.accent` |
| success | `Theme.success` |
| warn | `Theme.warn` |
| error | `Theme.error` |

### 9.3 Lifecycle & Animation

```
[create] → slide+fade in 0.20s (x+18 → 0, transparency 0→1)
        → hold `duration` (progress bar width 100%→0% linear)
        → slide+fade out 0.20s → Remove()
```

Queue `maxVisible=5`, overflow queued FIFO, `ClearToasts` lerps all out `0.15s`.

### 9.4 Implementation

Own `toastDrawings[]` + `ToastManager` singleton, reuses `Util:Create/Lerp/UpdateOffset`. Viewport listener reflows anchors. No per-toast RenderStepped — driven by shared single RenderStepped with job list.

---

## 10. Config & Persistence

`Flags` contract: every widget with `flag` exposes `Get/Set`. `Window:GetConfig() → JSON` (colors as `{h,s,v}, Alpha`), `LoadConfig(json)` iterates `Flags[flag]:Set(v)`. File helpers:

```lua
Window:SaveConfig(name)      -- serioushook/configs/{name}.json
Window:LoadConfigFile(name)
Window:ListConfigs() → string[]
Window:DeleteConfig(name)
Window:Autoload(name)        -- load on Initialize
```

`ConfigList` widget syncs to `Flags["__configlist"]` (or custom flag).

---

## 11. Input & Lifecycle

One `InputBegan` dispatches to `_began` queue unless `Window.dragging` (break), `InputEnded → _ended`, `InputChanged → _changed` + drag `Move(clamped)`. Popup priority: `ClosePopups` before opening new; `IsOverPopup` blocks Toggle/Slider hits. `ViewportSize` change re-centers or reflows toasts/keylist/watermark.

---

## 12. Example Usage

```lua
local SH = loadstring(game:HttpGet("https://raw.githubusercontent.com/.../SeriousHook.lua"))()

local Win = SH:Window{
  title = "SeriousHook | Private",
  size  = Vector2.new(540, 620),
  accent= Color3.fromRGB(105,90,255),
}

local Aim = Win:Page{name="Aimbot"}
local Vis = Win:Page{name="Visuals"}
local Main, Settings = Aim:MultiSection{tabs={"Main","Settings"}, side="left", height=200}
local Legit = Aim:Section{name="Legit", side="right"}

local t = Main:Toggle{name="Enabled", default=true, flag="aim_on", callback=function(v) print("aim",v) end}
t:AddColor{default=Color3.new(1,0,0), alpha=0.2, flag="aim_col", callback=function(c,a) end}
t:AddKeybind{default=Enum.KeyCode.E, mode="Toggle", flag="aim_key", callback=function(k,active) end}

Main:Slider{name="FOV", min=0, max=360, default=90, suffix="°", decimals=1, flag="fov"}
Main:Dropdown{name="Bone", options={"Head","Torso","Legs"}, default="Head", flag="bone"}
Main:MultiDropdown{name="Checks", options={"Visible","Team","Knocked"}, default={"Visible"}, min=1, flag="checks"}
Main:Textbox{name="Custom", placeholder="Enter...", flag="custom"}

Vis:Section{name="ESP"}:Toggle{name="Box", default=true, flag="box"}:AddColor{default=Color3.new(1,1,1), flag="box_col"}
Vis:Section{name="World"}:Slider{name="Brightness", min=0, max=3, default=1, decimals=0.01, flag="bright"}

local Cfg = Vis:Section{name="Configs"}:ConfigList()
Vis:Section{name="Configs"}:DuoButton{buttons={
  {"Save", function() Win:SaveConfig("default"); SH:Success("Saved!",2) end},
  {"Load", function() Win:LoadConfigFile("default"); SH:Success("Loaded!",2) end},
}}

Win:Watermark{enabled=true}
Win:Keylist{enabled=true}
Win:Cursor{enabled=true}
SH:SetToastPosition("bottomRight")
SH:Toast{title="SeriousHook", message="Loaded — press RightShift", type="success", duration=3}

Win:Initialize()
-- Win:Unload() on script close
```

---

## 13. Optimization — FPS-First Design

> **Goal:** < 0.8ms/frame overhead at 144 FPS on mid hardware (measured via `debug.profilebegin` / `stats`). Zero GC churn per frame.

### 13.1 Principles

- **Single RenderStepped** — one connection drives cursor, lerp queue, toast progress, watermark throttle, keylist resort. Ref creates N connections (`Cursor`, `Watermark ping`, each `Lerp`); SeriousHook coalesces to 1.
- **Throttle expensive work:** `fps/ping` every `0.25s` not every frame; toast progress every `0.05s`; cursor every frame but branchless.
- **No per-frame allocations:** pre-allocate `Vector2`, reuse tables, avoid `GetTextBounds` in RenderStepped (cache widths).
- **Lazy & pooled:** popups (dropdown/colorpicker/toast) Drawings created on open, `:Remove()` on close immediately; no hidden pool leak.
- **Hit-test early-out:** `MouseOverDrawing` is 4 compares; check `Window.isVisible and Page.open and Section.visible` before it.
- **Lerp queue not per-Lerp connection:** `Util:Lerp` pushes `{inst, from, to, t, dur}` to `LerpQueue`; single stepper interpolates and disconnects when done — avoids `N` RenderStepped per fade.

### 13.2 Concrete Budgets

| Cost | Budget | Technique |
|---|---|---|
| RenderStepped total | <0.4ms | Single connect, throttle 0.25s watermark, no `GetTextBounds` |
| Memory per Window | <180 Drawings | Reuse theme layers, toast cap 5 |
| GC per frame | 0 alloc | Reuse Vector2, cache bounds, avoid string.format in hot path |
| LoadImage | once per asset | `isfile` cache, no HttpGet repeat |
| Config JSON | <2ms save/load | Iterate Flags only, not Drawings |

### 13.3 Checklist (enforced in code review)

- [ ] No `RenderStepped:Connect` outside `Window:Initialize` + `ToastManager` (merged)
- [ ] `GetTextBounds` only on creation / `Set(text)` / `ViewportSize` — never per frame
- [ ] `MouseLocation()` cached once per Input event
- [ ] `LerpQueue` not `connection:Disconnect()` per call
- [ ] Toast `progressBar` width updated via `Size` lerp, not recreation
- [ ] `string.format` for watermark only on throttle tick

---

## 14. Implementation Phases

| Phase | Deliverable | Effort |
|---|---|---|
| 0 | `DESIGN.md` + `CHECKLIST.md` | 0.5d |
| 1 | Scaffold: `Theme, Util, Window/Page/Section/MultiSection` + `Move/Fade/Input` proof (`Label` renders) | 1d |
| 2 | Core widgets: `Toggle, Slider, Button/DuoButton, Dropdown, MultiDropdown` + popup `ClosePopups/IsOverPopup` | 1.5d |
| 3 | Pickers & Keybinds: `Colorpicker` HSV, `Keybind Hold/Toggle/Always` + `AddColor/AddKeybind` chaining, second picker | 2d |
| 4 | Overlays: `Watermark, Keylist, Cursor, ConfigList`, `Flags Get/Set`, `Unload`, viewport reflow | 1d |
| 5 | Toasts + Textbox/Divider + LerpQueue + perf pass | 1d |
| 6 | QA & Docs: res test, example script, perf profile | 0.5d |

**Exit criteria:** `Flags` JSON round-trip, toasts stack 5, no `Seveen` typo, no global leaks, <0.8ms/frame at 144Hz.

---

## 15. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Drawing leak on unload | Track `Drawings+Hidden+Connections`, `Unload` removes both |
| Popup z-fighting | `currentPopup` single-owner + `IsOverPopup` guard |
| Viewport resize breakage | `GetPropertyChangedSignal("ViewportSize")` reflow all |
| Executor file I/O variance | Guard `isfolder/isfile/makefolder/writefile` existence (ref:33) |
| FPS drop | §13 single RenderStepped + throttles |

---

## 16. Decisions Required Before Build

1. Size/accent: keep ref `504×604 / 50,100,255` or new `540×620 / 105,90,255`? *(proposed: new)*
2. Toast anchor: `bottomRight` (standard) vs `topRight`/`topCenter`?
3. Textbox in v1 or defer?
4. Single-file dist vs `src/` modules? *(proposed: both — build single)*
5. Fade key: `RightShift` (common) or `Insert`/`Z`?

---

*Approved design → exit plan mode → implement per CHECKLIST.md.*
