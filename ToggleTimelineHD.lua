-- ToggleTimelineHDv2.lua
-- Toggles the current timeline between HD (1920x1080) and its previous resolution.
--   First run: stashes current resolution, switches to HD.
--   Second run: restores the stashed resolution.
--
-- v2 changes:
--   * Guards against a missing/unreachable Resolve global.
--   * Verifies SetSetting() return values and aborts cleanly on failure
--     (no stash written if we could not actually change resolution; no stash
--     deleted if the restore did not take).
--   * Verifies GetSetting() returned usable values before computing.
--
-- Install:
--   macOS:   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Edit/
--   Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\
--   Linux:   ~/.local/share/DaVinciResolve/Fusion/Scripts/Edit/
--
-- Run from: Workspace > Scripts > Edit > ToggleTimelineHDv2

local TAG = "[ToggleTimelineHD v2]"

local function logf(fmt, ...)
    print(TAG .. " " .. string.format(fmt, ...))
end

local function err(msg)
    print(TAG .. " ERROR: " .. msg)
end

local HD_W, HD_H = "1920", "1080"
local FALLBACK_W, FALLBACK_H = "3840", "2160"

----------------------------------------------------------------------
-- 1. Resolve object
----------------------------------------------------------------------

if type(Resolve) ~= "function" and type(resolve) ~= "function" then
    err("Resolve global not found. Run this from inside DaVinci Resolve "
        .. "(Workspace > Scripts > Edit).")
    return
end

local okResolve, resolve = pcall(function()
    if type(Resolve) == "function" then return Resolve() end
    return _G.resolve and _G.resolve() or nil
end)

if not okResolve or not resolve then
    err("Could not obtain a Resolve handle. Is the scripting API enabled "
        .. "(Preferences > System > General > External scripting using: Local)?")
    return
end

local pm = resolve:GetProjectManager()
if not pm then
    err("ProjectManager unavailable.")
    return
end

local project = pm:GetCurrentProject()
if not project then
    err("No project is open.")
    return
end

local timeline = project:GetCurrentTimeline()
if not timeline then
    err("No active timeline. Open one in the Edit page and try again.")
    return
end

----------------------------------------------------------------------
-- 2. Helpers with checked return values
----------------------------------------------------------------------

-- SetSetting returns boolean in the Resolve API. Treat anything other than
-- explicit true as a failure.
local function setChecked(obj, key, value)
    local ok = obj:SetSetting(key, value)
    if ok ~= true then
        err(string.format("SetSetting(%s, %s) failed (returned %s).",
            key, tostring(value), tostring(ok)))
        return false
    end
    return true
end

local function getNonEmpty(obj, key)
    local v = obj:GetSetting(key)
    if v == nil or v == "" then return nil end
    return v
end

-- Nudge the playhead by one frame and back to force a viewer redraw.
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
-- 3. Per-timeline override
----------------------------------------------------------------------

if timeline:GetSetting("useCustomSettings") ~= "1" then
    if not setChecked(timeline, "useCustomSettings", "1") then
        err("Could not enable per-timeline custom settings. Aborting.")
        return
    end
end

----------------------------------------------------------------------
-- 4. Stash file (per project + timeline)
----------------------------------------------------------------------

local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "/tmp"
local rawKey = (project:GetName() or "proj") .. "__" .. (timeline:GetName() or "tl")
local safeKey = rawKey:gsub("[^%w]", "_")
local stashPath = home .. "/.resolve_tl_toggle_" .. safeKey .. ".txt"

local function readStash()
    local f = io.open(stashPath, "r")
    if not f then return nil end
    local w = f:read("*l")
    local h = f:read("*l")
    f:close()
    if w and h and w ~= "" and h ~= "" then return w, h end
    return nil
end

local function writeStash(w, h)
    local f, openErr = io.open(stashPath, "w")
    if not f then
        err("Could not open stash file for write: " .. tostring(openErr))
        return false
    end
    f:write(w .. "\n" .. h .. "\n")
    f:close()
    return true
end

local function deleteStash()
    os.remove(stashPath)
end

----------------------------------------------------------------------
-- 5. Toggle
----------------------------------------------------------------------

local curW = getNonEmpty(timeline, "timelineResolutionWidth")
local curH = getNonEmpty(timeline, "timelineResolutionHeight")
if not curW or not curH then
    err("Could not read current timeline resolution.")
    return
end

if curW == HD_W and curH == HD_H then
    -- Restore previous resolution.
    local sw, sh = readStash()
    local targetW, targetH

    if sw and sh then
        targetW, targetH = sw, sh
    else
        logf("No stash found for this timeline. Using fallback %sx%s.",
            FALLBACK_W, FALLBACK_H)
        targetW, targetH = FALLBACK_W, FALLBACK_H
    end

    local okW = setChecked(timeline, "timelineResolutionWidth", targetW)
    local okH = setChecked(timeline, "timelineResolutionHeight", targetH)
    if not (okW and okH) then
        err("Restore failed. Stash left in place so you can retry.")
        return
    end

    if sw and sh then deleteStash() end
    logf("Restored %s to %sx%s.", timeline:GetName(), targetW, targetH)
else
    -- Stash and switch to HD.
    if not writeStash(curW, curH) then
        err("Could not write stash. Aborting before changing resolution.")
        return
    end

    local okW = setChecked(timeline, "timelineResolutionWidth", HD_W)
    local okH = setChecked(timeline, "timelineResolutionHeight", HD_H)
    if not (okW and okH) then
        err("Switch to HD failed. Removing stash to keep state consistent.")
        deleteStash()
        return
    end

    logf("Stashed %sx%s, switched %s to %sx%s.",
        curW, curH, timeline:GetName(), HD_W, HD_H)
end

refreshViewer(timeline)
