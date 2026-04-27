# ToggleTimelineHD

A small Lua script for DaVinci Resolve that flips the active timeline's **"Use project settings"** checkbox with a single keystroke. Combined with a one-time setup, this lets you toggle the timeline between your **OCN resolution** (project setting) and **HD 1920x1080** (timeline custom setting) instantly.

Runs from **Workspace > Scripts > Edit** and is designed to be bound to a keyboard shortcut (such as `Ctrl+T`) for fast cycling.

## Why this exists

Common DIT and post scenario: you are cutting or transcoding on a high-resolution timeline (UHD, 6K, 8K, anamorphic, custom sensor sizes) and want a fast way to drop the timeline to HD for a quick render, client review, or editorial handoff, then jump straight back to your working OCN.

This is especially handy for **Premiere Pro proxy workflows** where editorial requires proxies that are a fractional reduction of the OCN (typically 1/2 or 1/4) while preserving the original aspect ratio. Bouncing the Resolve timeline to a proxy resolution for an export pass, then back to OCN for the master, normally means digging through Timeline Settings every time. This script collapses that into a single keystroke.

For non-standard sensor sizes (ARRI ALEXA 35 4.6K open gate, ALEXA Mini LF 4.5K, Sony Venice 8.6K, RED 8K VV, anamorphic captures), preserving aspect ratio is critical, and that is exactly what this approach does because both states are pre-baked by you in the Resolve UI before you ever press the shortcut.

## How it works

The script does one thing: it flips the timeline's `useCustomSettings` flag between `0` and `1`. That is the same checkbox you see in **Timeline Settings > Use project settings** at the bottom of the dialog.

- `useCustomSettings = 0` (Use project settings checked): timeline conforms to your project resolution (OCN).
- `useCustomSettings = 1` (Use project settings unchecked): timeline uses its own custom resolution (HD).

Because both resolution states are stored in Resolve's own settings and not manipulated by the script at runtime, the Deliver page is never disturbed and there is no aspect-ratio drift on render output.

## Features

- One-key toggle between OCN and HD timeline modes.
- Per-timeline. Each timeline carries its own custom resolution, so different timelines can toggle to different targets (HD, 2K DCI, half-OCN, etc.).
- Zero render path interference. No `SetRenderSettings` calls, no jump to the Deliver page on toggle.
- Forces a viewer redraw after the flip so you do not have to nudge the playhead manually.
- Defensive error handling: validated Resolve handle, checked `SetSetting()` return.

## Requirements

- DaVinci Resolve 18 or later (Free or Studio).
- External scripting enabled: **Preferences > System > General > External scripting using: Local**.

## Installation

Copy `ToggleTimelineHDv5.lua` into the Edit scripts folder for your OS:

- macOS: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Edit/`
- Windows: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\`
- Linux: `~/.local/share/DaVinciResolve/Fusion/Scripts/Edit/`

Restart Resolve (or just reopen the Workspace menu) and the script will appear under **Workspace > Scripts > Edit > ToggleTimelineHDv5**.

## One-time setup per timeline

Before the script does anything useful, the timeline needs to know what its "HD" state should look like. This is a one-time setup, done in the Resolve UI:

1. **Project Settings** (`Shift+9`): set Timeline resolution to your OCN (for example 3840x2160). This is the "OCN state".
2. **Timeline Settings** on your working timeline (right-click the timeline in the Media Pool > Timelines > Timeline Settings, or from the Timeline menu).
3. Uncheck **Use project settings**.
4. Set Timeline resolution to **1920x1080 HD** (or whatever proxy resolution you want, see the table below for proxy workflows).
5. Confirm **Mismatched resolution** is set to "Scale entire image to fit" so the OCN content fills the HD frame cleanly.
6. Click **OK**.

The current state of the checkbox does not matter at this point. The script will toggle from whatever state you are in.

Repeat steps 2 to 6 for every timeline you want to toggle. New timelines created later will need the same one-time setup.

## Usage

1. Open the timeline you want to toggle.
2. Run **Workspace > Scripts > Edit > ToggleTimelineHDv5**.
3. Run it again to toggle back.

Open **Workspace > Console** (set to Lua) if you want to see a confirmation log of the new state and effective resolution after each toggle.

## Keyboard shortcut (recommended)

To make this truly one-key, bind the script to a shortcut like `Ctrl+T` (or `Cmd+T` on macOS):

1. Open Resolve.
2. Go to **DaVinci Resolve > Keyboard Customization** (macOS: `Cmd+Option+K`, Windows/Linux: `Ctrl+Alt+K`).
3. Make sure the preset dropdown at the top is set to a **custom preset**, not "DaVinci Resolve". Default presets are read-only. If you do not have a custom preset yet, click the dropdown and choose **Save As New Preset**, give it a name, and save.
4. In the search box at the top right, type `ToggleTimelineHDv5`. The script appears under the Workspace > Scripts category.
5. Click the command, then click in the shortcut field on the right and press your desired combination. `Ctrl+T` on Windows/Linux or `Cmd+T` on macOS works well, but pick anything you have free.
6. If the combination is already in use, Resolve will warn you and let you reassign. Confirm if you are sure you do not need the existing binding.
7. Click **Save** in the bottom right.

After this, hitting your shortcut once flips the active timeline between OCN and HD. The same shortcut also works as a **Stream Deck** button via Bitfocus Companion or any tool that can fire a Resolve menu item or keystroke.

## Proxy workflow setup

For Premiere Pro proxy delivery you typically want exact fractional reductions of the OCN to preserve aspect ratio. Set the timeline's custom resolution (step 4 in the one-time setup above) to the appropriate fraction:

| OCN | 1/2 proxy | 1/4 proxy |
|---|---|---|
| 3840 x 2160 (UHD) | 1920 x 1080 | 960 x 540 |
| 4096 x 2160 (DCI 4K) | 2048 x 1080 | 1024 x 540 |
| 4448 x 3096 (ALEXA 35 4.6K Open Gate) | 2224 x 1548 | 1112 x 774 |
| 4608 x 2592 (ALEXA Mini LF 4.5K 16:9) | 2304 x 1296 | 1152 x 648 |
| 8192 x 4320 (Venice 2 8.6K 17:9) | 4096 x 2160 | 2048 x 1080 |

Because the resolution is stored on the timeline and not in the script, the same `ToggleTimelineHDv5.lua` works for any of these targets. You just decide what "off" mode means per timeline.

If you regularly need to bounce between three or more states (for example OCN, half, and quarter), Resolve's two-state checkbox cannot represent that on its own. In that case, use multiple timelines, each preconfigured to a different proxy resolution, and switch between them with the "Switch to Next Timeline" shortcut.

## Caveats

- The script assumes the timeline's custom resolution has been pre-configured. If you run the script on a timeline whose custom settings have never been touched, it will toggle into "use custom" mode but the resolution may match the project default, in which case nothing visible changes. Open Timeline Settings and complete the one-time setup.
- Resolve's **Image Scaling > Mismatched Resolution Files** setting (Project Settings) governs how clips reframe when timeline resolution changes. "Scale entire image to fit" is usually what you want for proxy work. "Center crop with no resizing" will reframe everything visibly on each toggle.
- Renaming or duplicating a timeline carries the custom resolution with it, but a freshly created timeline does not. Each new timeline you intend to toggle needs the one-time setup.

## Files

- `ToggleTimelineHDv5.lua`: current version.

## Version history

- **v5**: pure `useCustomSettings` toggle. No render path manipulation. Current.
- **v4**: synced timeline working and output resolutions, plus restored project-level Deliver settings. Caused the Deliver page to grab focus on toggle.
- **v3**: added Deliver page Export Video preservation via `SetRenderSettings`. Introduced black borders on render output due to mismatched timeline output vs working resolution.
- **v2**: added error handling for Resolve handle and `SetSetting()` returns.
- **v1**: initial stash-and-swap implementation.

## License

MIT.
