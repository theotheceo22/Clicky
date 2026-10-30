# Clicky — autoclicker for macOS

A native SwiftUI autoclicker for Apple Silicon Macs (macOS 14 Sonoma or later).

## Build & run

1. Unzip, then open **Terminal** in the `Clicky` folder.
2. If you've never compiled anything on this Mac, install Apple's free tools once:
   `xcode-select --install`
3. Build and launch:
   ```
   chmod +x build.sh
   ./build.sh --install
   ```
   (`--install` copies it to /Applications. Leave it off to just run it from `build/`.)

## First launch: grant Accessibility

macOS only lets apps send clicks if they have Accessibility access.
Click **Grant** in the app → **System Settings › Privacy & Security › Accessibility** → turn **Clicky** on.
The amber banner disappears by itself once access is on.

## Using it

| | |
|---|---|
| **Big button** | Starts after a 3-second countdown (so you can move the mouse to your target). Click again to stop. |
| **⌥⌘K** | Start/stop from anywhere, instantly — no countdown. |
| **Esc** | Stops clicking (only captured while running). |
| **Speed** | 1–100 clicks per second, with quick presets. |
| **Button / Click type** | Left, right or middle; single or double clicks. |
| **Target** | *Cursor* clicks wherever the pointer is. *Fixed* clicks one screen spot — press **Pick point**, hover the target for 3 seconds, and a marker flashes to confirm. |
| **Stop after** | Automatically stop after N clicks. |
| **Humanize** | Randomizes each interval by ±25% so the rhythm isn't robotic. |
| **Menu bar icon** | Start/stop and reopen the window even when it's closed. |

Settings are remembered between launches.

## Troubleshooting

- **Clicks don't happen even though access is on:** after rebuilding, macOS treats it as a new app. In Accessibility settings, select Clicky, remove it with **−**, then launch Clicky and grant again.
- **⌥⌘K does nothing:** another app may own that shortcut. Change it in `Sources/ClickerModel.swift` (search for `kVK_ANSI_K`) and rebuild.
- Use responsibly — many online games and sites prohibit autoclickers.
