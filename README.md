- [日本語はこちら](./README.ja.md)

<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.svg" width="256" />
    <p>
    <h3>Thunderbolt</h3>
    <div>A Hammerspoon script for switching and recognizing windows at the speed of thought.</div>
    </p>
    <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml">
      <img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" />
    </a>
    <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE">
      <img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" />
    </a>
</div>

---

- 🔠 **Window Hints**
    - Switch windows with app icons + key hints
        - Automatically assigns the first letter of each app name as the hint prefix
        - If multiple windows share the same prefix, narrow them down with additional key input
    - Windows completely hidden by others (sampling-based approximation) are shown at the bottom in a dock-style layout with previews
    - Highlights the active window with an overlay
- 🔳 **Focus Border**
    - Briefly highlights the border of the newly focused window
- ↩️ **Focus Back**
    - Hotkey to jump back to the previously active window

## Demo Video

[![JINRAI Demo](https://img.youtube.com/vi/clwLqNw0kXw/hqdefault.jpg)](https://youtu.be/clwLqNw0kXw?si=gdetaK7lY0Eovjpp)

## Setup

```bash
git clone https://github.com/tadashi-aikawa/jinrai /path/to/jinrai
```

Add this to `~/.hammerspoon/init.lua`:

```lua
local jinrai = dofile("/path/to/jinrai/init.lua")

jinrai.setup({
  focus_border = {},
  window_hints = {},
  focus_back = {},
})
```

If you omit `focus_border`, `window_hints`, or `focus_back`, that module is disabled.

## Configuration Example

```lua
local jinrai = dofile("/path/to/jinrai/init.lua")

jinrai.setup({
  focus_border = {
    borderWidth = 10,
    borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
    outlineWidth = 2,
    outlineColor = { red = 0, green = 0, blue = 0, alpha = 0.70 },
    duration = 0.5,
    fadeSteps = 18,
    cornerRadius = 10,
    minWindowSize = 480,
  },
  window_hints = {
    hintChars = { "A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M" },
    appPrefixOverrides = {
      {
        match = { bundleID = "md.obsidian", titleGlob = "*- minerva - Obsidian*" },
        prefix = "M",
      },
      {
        match = { bundleID = "md.obsidian" },
        prefix = "O",
      },
      {
        match = { bundleID = "com.google.Chrome" },
        prefix = "GC",
      },
    },
    hotkeyModifiers = { "alt" },
    hotkeyKey = "f20",
    iconSize = 72,
    titleMaxSize = 72,
    centerCursor = true,
    onError = function(err)
      hs.alert.show("Window Hints error: " .. tostring(err), 3)
    end,
  },
  focus_back = {
    hotkeyModifiers = { "option" },
    hotkeyKey = "w",
    centerCursor = true,
  },
})
```

## Focus Border Options

| Option          | Default                                                   | Description                                |
| --------------- | --------------------------------------------------------- | ------------------------------------------ |
| `borderWidth`   | `10`                                                      | Main border width (px)                     |
| `borderColor`   | `{ red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 }`| Main border color                          |
| `outlineWidth`  | `2`                                                       | Outer outline width (px)                   |
| `outlineColor`  | `{ red = 0, green = 0, blue = 0, alpha = 0.70 }`         | Outer outline color                        |
| `duration`      | `0.5`                                                     | Fade-out duration (seconds)                |
| `fadeSteps`     | `18`                                                      | Number of fade-out steps                   |
| `cornerRadius`  | `10`                                                      | Corner radius (px)                         |
| `minWindowSize` | `480`                                                     | Minimum window size to display (px)        |

## Window Hints Options

| Option         | Default       | Description |
| -------------- | ------------- | ----------- |
| `hotkeyModifiers`  | `{ "alt" }`    | Hotkey modifiers for showing hints |
| `hotkeyKey`        | `"f20"`         | Hotkey for showing hints |
| `hintChars`        | `A-Z (QWERTY)` | Array of hint characters |
| `appPrefixOverrides` | `nil`         | Override leading prefixes via rule array (`window:title()` `glob` support, 1-2 char prefixes) |
| `iconSize`         | `72`            | App icon size (px) |
| `titleMaxSize`     | `72`            | Max title length shown |
| `showTitles`       | `true`          | Whether to show title rows |
| `occlusionSamplingEnabled` | `true`   | Whether occlusion sampling is dynamically adjusted |
| `occlusionSamplingBaseWidth` | `1920`  | Base window width for occlusion sampling (px) |
| `occlusionSamplingBaseHeight` | `1080` | Base window height for occlusion sampling (px) |
| `occlusionSamplingMinCols` | `4`       | Minimum sampling columns for occlusion check |
| `occlusionSamplingMinRows` | `4`       | Minimum sampling rows for occlusion check |
| `occlusionSamplingMaxCols` | `8`       | Maximum sampling columns for occlusion check |
| `occlusionSamplingMaxRows` | `8`       | Maximum sampling rows for occlusion check |
| `onSelect`         | `nil`           | Callback on window selection |
| `onError`          | `nil`           | Callback on error |
| `centerCursor`     | `false`         | Move cursor to window center after selection |
| `centerCursorOnStart` | `false`      | Move cursor to active window center at startup |

Occlusion is determined by approximation using sample points inside each target window.
When `occlusionSamplingEnabled=true`, the sampling grid is dynamically adjusted within the range from `occlusionSamplingMin*` to `occlusionSamplingMax*`, based on `occlusionSamplingBaseWidth/Height`.

### appPrefixOverrides

`appPrefixOverrides` lets you override the leading hint prefix per window.
Rules are evaluated from top to bottom, and the first matching rule is applied.

#### appPrefixOverrides Definition

```lua
appPrefixOverrides = {
  {
    match = {
      bundleID = "md.obsidian",   -- optional
      titleGlob = "Minerva*",     -- optional (`window:title()` target, supports `*` and `?`)
    },
    prefix = "M",                 -- 1 or 2 chars. Each char must be included in hintChars
  },
}
```

#### appPrefixOverrides Behavior

- Either `match.bundleID` or `match.titleGlob` is required
- `titleGlob` is case-sensitive
- The legacy dictionary format (`["bundleID"] = "T"`) is no longer supported
- Display key sets are automatically adjusted to stay prefix-free (for example, if `G` and `GC` conflict, they become `GA` and `GC`)
- If no rule matches, the first letter of the app name is used; if that letter is not in `hintChars`, it falls back to `hintChars[1]`
- Invalid `prefix` values (characters not in `hintChars`, 3+ chars, etc.) raise errors

There are many more customization options. See `DEFAULT_CONFIG` in `window_hints.lua` for details.

## Focus Back Options

| Option         | Default          | Description |
| -------------- | ---------------- | ----------- |
| `hotkeyModifiers`  | `{ "option" }`    | Hotkey modifiers |
| `hotkeyKey`        | `"w"`             | Hotkey (`nil` to disable) |
| `urlEvent`         | `nil`             | URL scheme name (trigger via `hammerspoon://<name>`) |
| `centerCursor`     | `false`           | Move cursor to window center after switching |
| `stateSync`        | `nil`             | State sync settings to compensate for missed events (see below) |

Pressing repeatedly lets you toggle between two windows.

### stateSync

`stateSync` helps prevent drift in `focus_back` history tracking.

In most cases, macOS focus notifications are sufficient. However, some apps do not emit reliable notifications when switching tabs, which can cause `focus_back` to jump to unexpected locations.
If you enable `stateSync`, JINRAI periodically checks window state and corrects history.

#### Examples where it helps

- Right after switching tabs, `focus_back` does not return to the tab you expected
- When moving between apps, `focus_back` targets are unstable

#### `stateSync` Definition

| Option         | Default          | Description |
| -------------- | ---------------- | ----------- |
| `interval`         | `0.2`            | Sync interval (seconds) |
| `targetApps`       | `nil`            | Array of target app names or bundle IDs (`nil` for all apps) |
| `historyScope`     | `"window"`      | History update scope (`"window"` or `"application"`) |

##### `historyScope` Behavior:

- `"window"`: Updates history at the window (tab) level
- `"application"`: Does not update history when moving tabs within the same app

#### Ghostty Example

Ghostty needs this because each tab has a different window ID, and tab switches are not delivered to JINRAI (hammerspoon) as focus notifications.

```lua
focus_back = {
  stateSync = {
    interval = 0.15,
    targetApps = { "com.mitchellh.ghostty" },
    historyScope = "application",
  },
}
```

> [!NOTE]
> If you know a smarter solution, I'd love to hear it.

## Test

Run unit tests with `busted`.

```bash
busted
```

If you want to run specific tests:

```bash
busted spec/focus_back_spec.lua
busted spec/init_spec.lua
```

## License

MIT
