-- SeriousHook/src/init.lua
-- Public entry. This file is the "root" when concatenating via build.lua.
-- It creates the SeriousHook namespace and attaches core subsystems.
-- Everything else (Theme, Util, Window, Page, Section, widgets, overlays, Toasts, Config)
-- is concatenated AFTER this in dependency order, each file closing over SeriousHook.

local SeriousHook = {}
SeriousHook.__index = SeriousHook

-- Folders (Splix-style isfolder/makefolder guards)
SeriousHook.folders = {
	main    = "serioushook",
	assets  = "serioushook/assets",
	configs = "serioushook/configs",
	toasts  = "serioushook/toasts",
}

if not isfolder(SeriousHook.folders.main) then makefolder(SeriousHook.folders.main) end
if not isfolder(SeriousHook.folders.assets) then makefolder(SeriousHook.folders.assets) end
if not isfolder(SeriousHook.folders.configs) then makefolder(SeriousHook.folders.configs) end

-- Shared state
SeriousHook.Flags    = {}
SeriousHook.Drawings = {}
SeriousHook.Hidden   = {}
SeriousHook.Connections = {}
SeriousHook._began  = {}
SeriousHook._ended  = {}
SeriousHook._changed = {}
SeriousHook.shared  = { initialized = false, fps = 0, ping = 0 }

-- Forward declarations (filled by concatenated modules)
SeriousHook.Theme        = {}
SeriousHook.Util         = {}
SeriousHook.Window       = {}
SeriousHook.Page         = {}
SeriousHook.Section      = {}
SeriousHook.MultiSection = {}
SeriousHook.Toasts       = {}

-- Expose as the return value for loadstring() usage
return SeriousHook
