# SeriousHook — Build Checklist
> Companion to `DESIGN.md`. Single source of truth for what ships in v1 and how FPS stays >144.

---

## 1. Deliverables
- [x] `DESIGN.md` — full spec (this task)
- [x] `CHECKLIST.md` — this file
- [x] `SeriousHook.lua` — single-file dist (loadstring-ready) — 4801 lines built from 21 src files
- [x] `src/` modular layout (dev)
- [x] `example.lua` — runnable demo from DESIGN §12
- [ ] `README.md` — install + API quickstart

---

## 2. Foundation
- [x] **Folders** — `serioushook/`, `serioushook/assets/`, `serioushook/configs/` created with `isfolder/makefolder` guards (ref:33)
- [x] **Theme** — `Theme.lua` with `accent/surface0-2/border/borderMuted/text/textDim/textOutline/success/warn/error/cursorOuter/font/textsize`, `Theme:Set(key, Color3)` live update, `OnChanged/Unsubscribe`
- [x] **Util** — `Size, Position, Create(8 kinds), Remove, UpdateOffset, UpdateTransparency, MouseOverDrawing, GetTextBounds, LoadImage, Lerp(queue), Combine, clamp`
- [x] **Singleton** — `SeriousHook = {Flags={}, Drawings={}, Hidden={}, Connections={}, _began={}, _ended={}, _changed={}, _lerpQueue={}, shared={initialized,fps,ping}}`
- [x] **Single RenderStepped** — one connection in `Window:Initialize` drives all (cursor + lerp queue + toast + watermark throttle)
- [x] **Input dispatch** — 3× `UserInputService` connects → queues, `ViewportSize` listener → reflow

---

## 3. Window / Navigation
- [x] **Window** `SeriousHook:Window{title,size,accent,fadeKey,draggable}` — layers `main>accent>outer>innerBorder>outline2>tabHost` + title
  - [x] `Window:Move(pos)` clamped `[5, Viewport-X-W-5]`
  - [x] `Window:Fade()` lerps `Drawings` 0.25s, toggles cursor/MouseIcon
  - [x] `Window:ClosePopups()` / `IsOverPopup()` single-owner
  - [x] `Window:Unload()` disconnect + Remove all
  - [x] Drag: `began` on `main` header 20px, `changed` Move, `ended` stop
  - [x] `Window:Initialize()` show first page + init overlays + fade n
  - [x] Fade key: bindings to `Window:Fade()`
- [x] **Page** `Window:Page{name}` — pills `GetTextBounds+20`, active color `surface1` vs `surface0`, `Show()`, click handler
- [x] **Section** `Page:Section{name, side}` — container `inline>outline>frame+accent 2px` + title, `currentY` axis, `Update()`
- [x] **MultiSection** `Page:MultiSection{tabs, side, height}` — header + tab row, `SetActive`, returns `table.unpack(sections)`

---

## 4. Widgets
### Must-have (v1)
- [x] **Label** `{name, centered}` → `Set(text)`
- [x] **Divider** `{text?}` — line *(new)*
- [x] **Toggle** `{name, default, flag, callback}` → `Get/Set`, box 15×15
  - [x] **Toggle:AddColor** `{name, default, alpha?, flag}` → `Get/Set`, pill 30×15, stack -34, dual `-(60+8)`
