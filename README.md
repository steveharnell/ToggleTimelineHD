# ToggleTimelineHD

A small Lua script for DaVinci Resolve that toggles the current timeline between **HD (1920x1080)** and its previous resolution. Runs from **Workspace > Scripts > Edit** and can be bound to a keyboard shortcut (such as `Ctrl+T`) for one-key cycling.

## Why this exists

Common DIT and post scenario: you are cutting or transcoding on a high-resolution timeline (UHD, 6K, 8K, anamorphic, custom sensor sizes) and need a fast way to flip down to a smaller delivery or proxy resolution for a quick render, client review, or editorial handoff, then jump straight back to your working resolution.

This is especially handy for **Premiere Pro proxy workflows** where editorial requires proxies to be a fractional reduction of the OCN (typically 1/2 or 1/4) while maintaining the original aspect ratio. Bouncing the Resolve timeline to the proxy resolution for an export pass, then back to OCN for the master, normally means digging through Timeline Settings every time. This script collapses that into a single keystroke.

For non-standard sensor sizes (ARRI ALEXA 35 4.6K open gate, ALEXA Mini LF 4.5K, Sony Venice 8.6K, RED 8K VV, anamorphic captures), the fact that aspect ratio is preserved automatically when you change just width and height in matched proportion makes this much safer than a manual edit where it is easy to type the wrong number and squeeze the image.

## Features

- One script, two states. First run stashes your current resolution and switches to HD, second run restores it.
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

## Keyboard shortcut (recommended)

To make this truly one-key, bind the script to a shortcut like `Ctrl+T` (or `Cmd+T` on macOS):

1. Open Resolve.
2. Go to **DaVinci Resolve > Keyboard Customization** (macOS: `Cmd+Option+K`, Windows/Linux: `Ctrl+Alt+K`).
3. Make sure the preset dropdown at the top is set to a **custom preset**, not "DaVinci Resolve". The default presets are read-only. If you do not have a custom preset yet, click the dropdown and choose **Save As New Preset**, give it a name, and save.
4. In the search box at the top right, type `ToggleTimelineHDv2`. The script should appear, usually filed under the Workspace > Scripts category.
5. Click the command, then click in the shortcut field on the right and press your desired combination. `Ctrl+T` is a reasonable choice on Windows/Linux, `Cmd+T` on macOS, but pick anything you have free.
6. If the combination is already in use, Resolve will warn you and let you reassign or cancel. Confirm the reassignment if you are sure you do not need the existing binding.
7. Click **Save** in the bottom right.

After this, hitting your shortcut once flips the active timeline to HD, hitting it again flips it back. No menu hunting, no settings dialogs.

The same script and shortcut also works nicely as a **Stream Deck** button via Bitfocus Companion or any tool that can fire a Resolve menu item or keystroke.

## Configuration

Two constants at the top of the script control behavior:

```lua
local HD_W, HD_H = "1920", "1080"
local FALLBACK_W, FALLBACK_H = "3840", "2160"
```

- `HD_W` / `HD_H`: the target resolution to toggle to. Change these if you want the script to flip to something other than HD.
- `FALLBACK_W` / `FALLBACK_H`: only used if you run the restore branch on a timeline that has no stash on file (for example, a timeline that was already at the target resolution when you first ran the script).

### Tip for proxy workflows

For Premiere Pro proxy delivery you typically want exact fractional reductions of the OCN to preserve aspect ratio cleanly. Set `HD_W` / `HD_H` to whatever fraction of your OCN you need:

| OCN | 1/2 proxy | 1/4 proxy |
|---|---|---|
| 3840 x 2160 (UHD) | 1920 x 1080 | 960 x 540 |
| 4096 x 2160 (DCI 4K) | 2048 x 1080 | 1024 x 540 |
| 4448 x 3096 (ALEXA 35 4.6K Open Gate) | 2224 x 1548 | 1112 x 774 |
| 4608 x 2592 (ALEXA Mini LF 4.5K 16:9) | 2304 x 1296 | 1152 x 648 |
| 8192 x 4320 (Venice 2 8.6K 17:9) | 4096 x 2160 | 2048 x 1080 |

If you regularly bounce between more than two resolutions (for example OCN, half, and quarter), duplicate the script under different filenames (`ToggleTimelineHalf.lua`, `ToggleTimelineQuarter.lua`) with different `HD_W` / `HD_H` values, and bind each to its own shortcut.

## How it works

- Reads the current timeline width and height with `Timeline:GetSetting("timelineResolutionWidth"/"Height")`.
- Sets `useCustomSettings = "1"` on the timeline so resolution changes affect that timeline only, not the project default.
- Compares current resolution to the target HD values:
  - If not at HD: writes the current width/height to a small stash file in `$HOME` keyed by project + timeline name, then sets the timeline to HD.
  - If at HD: reads the stash, sets the timeline back to those values, deletes the stash.
- Calls `Timeline:SetCurrentTimecode()` with a one-frame nudge and back to force the viewer to recomposite at the new resolution.

Stash files live at `~/.resolve_tl_toggle_<project>__<timeline>.txt` and contain two lines (width, height). They are deleted automatically on restore. Safe to clean up by hand if you ever want to reset a timeline's stashed state.

## Known caveats

- Resolve's **Image Scaling > Mismatched Resolution** setting (Project Settings) determines how clips reframe when timeline resolution changes. If you have it set to something like "Center crop with no resizing," your framing will visibly shift on toggle. "Scale entire image to fit" or "Scale full frame with crop" usually behave best for proxy work.
- The viewer-refresh nudge stays inside the same second to avoid crossing minute or hour boundaries on very short timelines. On 99% of timelines this is invisible. If you ever see the viewer still not refreshing, increase the nudge to 2 or 3 frames in the `refreshViewer` function.
- Because the stash is keyed by name, renaming a timeline between toggles will orphan its stash. Not destructive, just means the next restore on that timeline falls back to `FALLBACK_W` / `FALLBACK_H`.

## Files

- `ToggleTimelineHDv2.lua`: current version with full error handling.

## License

MIT.
