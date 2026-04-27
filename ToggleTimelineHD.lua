-- ToggleTimelineHDv5.lua
-- Toggles the active timeline's "Use project settings" checkbox.
--
-- Setup (one time per timeline you want to toggle):
--   1. Set your project resolution to your OCN (e.g. 3840x2160) in
--      File > Project Settings.
--   2. Open Timeline Settings on the target timeline (right-click the
--      timeline in the Media Pool > Timelines > Timeline Settings, or
--      from the Timeline menu).
--   3. UNCHECK "Use project settings".
--   4. Set Timeline resolution to 1920x1080 HD.
--   5. Click OK. Optionally re-check "Use project settings" so you start
--      at OCN; the script will toggle into HD on first run either way.
--
-- After that, hitting your shortcut (or running this script) flips
-- between OCN and HD with no Deliver page disruption.
--
-- v5 changes vs v4:
--   * Pure toggle of `useCustomSettings`. No stash files, no project-level
--     manipulation, no SetRenderSettings (which was causing the unwanted
--     jump to the Deliver page).
--   * Whatever you have configured in the timeline's custom settings is
--     what HD mode will use. Whatever the project settings are is what
--     OCN mode will use. Both states are pre-baked, so nothing drifts.
--
-- Install:
--   macOS:   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Edit/
--   Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\
--   Linux:   ~/.local/share/DaVinciResolve/Fusion/Scripts/Edit/

local TAG = "[ToggleTimelineHD v5]"

local function logf(fmt, ...)
    print(TAG .. " " .. string.format(fmt, ...))
end
local function err(msg) print(TAG .. " ERROR: " .. msg) end

----------------------------------------------------------------------
-- Resolve handle
----------------------------------------------------------------------

if type(Resolve) ~= "function" and type(resolve) ~= "function" then
    err("Resolve global not found.")
    return
end

local okResolve, resolve = pcall(function()
    if type(Resolve) == "function" then return Resolve() end
    return _G.resolve and _G.resolve() or nil
end)

if not okResolve or not resolve then
    err("Could not obtain a Resolve handle.")
    return
end

local pm = resolve:GetProjectManager()
if not pm then err("ProjectManager unavailable.") return end
local project = pm:GetCurrentProject()
if not project then err("No project open.") return end
local timeline = project:GetCurrentTimeline()
if not timeline then err("No active timeline.") return end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function getNonEmpty(obj, key)
    local v = obj:GetSetting(key)
    if v == nil or v == "" then return nil end
    return v
end

local function refreshViewer(tl)
    local tc = tl:GetCurrentTimecode()
    if not tc or tc == "" then return end
    local h, m, s, sep, f = tc:match("(%d+):(%d+):(%d+)([:;])(%d+)")
    if not h then return end
    f = tonumber(f)
    if not f then return end
    local newF = (f > 0) and (f - 1) or (f + 1)
    local nudged = string.format("%s:%s:%s%s%02d", h, m, s, sep, newF)
    tl:SetCurrentTimecode(nudged)
    tl:SetCurrentTimecode(tc)
end

----------------------------------------------------------------------
-- Toggle useCustomSettings
----------------------------------------------------------------------

local current = timeline:GetSetting("useCustomSettings")
local nextValue = (current == "1") and "0" or "1"

local ok = timeline:SetSetting("useCustomSettings", nextValue)
if ok ~= true then
    err(string.format("SetSetting(useCustomSettings, %s) returned %s.",
        nextValue, tostring(ok)))
    return
end

local mode = (nextValue == "1") and "CUSTOM (timeline)" or "PROJECT"
local effW = getNonEmpty(timeline, "timelineResolutionWidth")
local effH = getNonEmpty(timeline, "timelineResolutionHeight")
logf("%s now using %s settings: %s x %s",
    timeline:GetName(), mode, tostring(effW), tostring(effH))

refreshViewer(timeline)
