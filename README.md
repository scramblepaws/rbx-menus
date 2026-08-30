# SeriousHook

A fast, module-friendly Luau menu library for Roblox executors (Synapse, Script-Ware, etc.).
Built on the Drawing API — retained widget tree, single RenderStepped loop, FPS-first.

## Install

```lua
local SH = loadstring(game:HttpGet("https://raw.githubusercontent.com/you/SeriousHook/main/SeriousHook.lua"))()
```

Or drop `SeriousHook.lua` next to your script and `dofile` / require it locally.

## Quick start

```lua
local Win = SH:Window{
	title   = "Menu",
	size    = Vector2.new(540, 620),
	accent  = Color3.fromRGB(105, 90, 255),
	fadeKey = Enum.KeyCode.RightShift,
}

local Aim  = Win:Page{name = "Aimbot"}
local Vis  = Win:Page{name = "Visuals"}

Aim:Toggle{name = "Enabled", default = true, flag = "aim_on", callback = print}
Aim:Slider{name = "FOV",  min = 0, max = 360, default = 90, suffix = "°", flag = "fov"}
Aim:Dropdown{name = "Bone", options = {"Head","Torso"}, default = "Head", flag = "bone"}
Aim:Colorpicker{name = "Color", default = Color3.new(1,0,0), flag = "color"}

Vis:Section{name = "ESP"}:Toggle{name = "Boxes", default = true}

Win:Watermark{enabled = true}
Win:Cursor{enabled = true}
SH:SetToastPosition("bottomRight")
SH:Toast{title = "SeriousHook", message = "Loaded", type = "success", duration = 3}

Win:Initialize()
```

## API

- `SH:Window{...}` → Window (draggable, fade toggle, pages)
- `Win:Page{name}` → Page (clickable tabs)
- `Page:Section{name, side}` → Section (widget container)
- `Page:MultiSection{tabs, side, height}` → multiple sections sharing a host
- Widgets: `Label`, `Divider`, `Toggle`, `Slider`, `Button`, `DuoButton`, `Dropdown`, `MultiDropdown`, `Textbox`, `Keybind`, `Colorpicker`, `ConfigList`
- Overlays: `Watermark`, `Keylist`, `Cursor`
- Toasts: `SH:Toast{...}`, `SH:Notify/Success/Warn/Error/ClearToasts/SetToastPosition`
- Config: `Win:SaveConfig/LoadConfig/ListConfigs/DeleteConfig/Autoload`

## Add a module

Drop a file into `src/widgets/` or `src/overlays/` and require/concatenate it — widgets patch `SectionProto`, overlays patch `Window`.

## Build from src/

```lua
-- Run in a Lua environment with filesystem access:
dofile("build.lua")   -- concatenates src/ into SeriousHook.lua
```

## License

MIT
