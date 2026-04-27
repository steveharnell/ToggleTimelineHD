# ToggleTimelineHD

A small Lua script for DaVinci Resolve that toggles the current timeline between **HD (1920x1080)** and its previous resolution. Runs from **Workspace > Scripts > Edit** and can be bound to a keyboard shortcut or fired from a Stream Deck.

Useful when you are cutting on a high-resolution timeline (UHD, 6K, 8K, anamorphic, custom sensor sizes) and need a one-click way to flip down to HD for a quick review render, client deliverable, or proxy session, then jump back to your working resolution without hunting through Timeline Settings.

## Features

- One script, two states: first run stashes your current resolution and switches to HD, second run restores it.
- Per-timeline override only. Your project defaults are never touched.
- Stash files are keyed by project name plus timeline name, so multiple timelines can be toggled independently without clobbering each other.
- Forces a viewer redraw after every change, so you do not have to nudge the playhead manually.
- Defensive error handling: validated Resolve handle, checked `SetSetting()` returns, atomic stash writes (no orphaned stash if a `SetSetting` call fails mid-toggle).

## Requirements

- DaVinci Resolve 18 or later (Free or Studio).
- External scripting enabled: **Preferences > System > General > External scripting using: Local**.

## Installation

Copy `ToggleTimelineHDv2.lua` into the Edit scripts folder for your OS:

- macOS: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Edit/`
- Windows: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\`
- Linux: `~/.local/share/DaVinciResolve/Fusion/Scripts/Edit/`

Restart Resolve (or just reopen the Workspace menu) and the script will appear under **Workspace > Scripts > Edit > ToggleTimelineHDv2**.

## Usage

1. Open the timeline you want to toggle.
2. Run **Workspace > Scripts > Edit > ToggleTimelineHDv2**.
3. Run it again to restore.

Optional but recommended: assign a keyboard shortcut via **DaVinci Resolve > Keyboard Customization**, search for the script name, and bind it to whatever key you like. It also works nicely as a Stream Deck button via Bitfocus Companion or any tool that can fire Resolve menu items.

## Configuration

Two constants at the top of the script control behavior:

```lua
local HD_W, HD_H = "1920", "1080"
local FALLBACK_W, FALLBACK_H = "3840", "2160"
```

- `HD_W` / `HD_H`: the target resolution to toggle to. Change these if you want the script to flip to something other than HD (for example 1280x720 for proxies, or DCI 2K).
- `FALLBACK_W` / `FALLBACK_H`: only used if you run the restore branch on a timeline that has no stash on file (for example, a timeline that was already HD when you first ran the script). Set this to whatever you want the "default upper resolution" to be for your typical project.

## How it works

- Reads the current timeline width and height with `Timeline:GetSetting("timelineResolutionWidth"/"Height")`.
- Sets `useCustomSettings = "1"` on the timeline so resolution changes affect that timeline only, not the project default.
- Compares current resolution to the target HD values:
  - If not at HD: writes the current width/height to a small stash file in `$HOME` keyed by project + timeline name, then sets the timeline to HD.
  - If at HD: reads the stash, sets the timeline back to those values, deletes the stash.
- Calls `Timeline:SetCurrentTimecode()` with a one-frame nudge and back to force the viewer to recomposite at the new resolution.

Stash files live at `~/.resolve_tl_toggle_<project>__<timeline>.txt` and contain two lines (width, height). They are deleted automatically on restore. Safe to clean up by hand if you ever want to reset a timeline's stashed state.

## Known caveats

- Resolve's **Image Scaling > Mismatched Resolution** setting (Project Settings) determines how clips reframe when timeline resolution changes. If you have it set to something like "Center crop with no resizing," your framing will visibly shift on toggle. "Scale entire image to fit" or "Scale full frame with crop" usually behave best for HD review.
- The viewer-refresh nudge stays inside the same second to avoid crossing minute or hour boundaries on very short timelines. On 99% of timelines this is invisible. If you ever see the viewer still not refreshing, increase the nudge to 2 or 3 frames in the `refreshViewer` function.
- Because the stash is keyed by name, renaming a timeline between toggles will orphan its stash. Not destructive, just means the next restore on that timeline falls back to `FALLBACK_W` / `FALLBACK_H`.

## Files

- `ToggleTimelineHDv2.lua`: current version with full error handling.

## License

MIT.
