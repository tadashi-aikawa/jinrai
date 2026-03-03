<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.svg" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>A Hammerspoon script for switching and recognizing windows at the speed of thought.</div>
    </p>
    <p>
        English | <a href="./README.ja.md">日本語</a>
    </p>
    <p>
        <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml">
          <img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" />
        </a>
        <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE">
          <img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" />
        </a>
    </p>
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

## Developer Blog Post (Japanese)

[📘至高のウィンドウ切り替えを目指して『JINRAI(迅雷)』をつくった - Minerva](https://minerva.mamansoft.net/2026-03-01-jinrai-ultimate-window-switching)

## Setup

Install with Git + symlink:

```bash
git clone https://github.com/tadashi-aikawa/jinrai /path/to/jinrai
ln -sfn /path/to/jinrai/Jinrai.spoon ~/.hammerspoon/Spoons/Jinrai.spoon
```

Add this to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("Jinrai")

spoon.Jinrai:setup({
  focus_border = {},
  window_hints = {},
  focus_back = {},
})
```

If you omit `focus_border`, `window_hints`, or `focus_back`, that module is disabled.

To update:

```bash
git -C /path/to/jinrai pull
```

## Configuration Example

```lua
hs.loadSpoon("Jinrai")

spoon.Jinrai:setup({
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
    focusBackKey = "i",
    directionKeys = {
      left = "h",
      down = "j",
      up = "k",
      right = "l",
      upLeft = "y",
      upRight = "u",
      downLeft = "b",
      downRight = "n",
    },
    swapWindowFrameSelectModifiers = { "shift" },
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
| `iconSize`         | `72`            | App icon size (px) |
| `keyBoxSize`       | `72`            | Key box height (px) |
| `keyBoxMinWidth`   | `72`            | Minimum key box width (px) |
| `keyBoxHorizontalPadding` | `10`     | Left/right padding inside key box (px) |
| `keyGap`           | `0`             | Gap between app icon and key box (px) |
| `padding`          | `12`            | Inner padding of the whole hint badge (px) |
| `fontName`         | `nil`           | Font name for key and title text (`nil` uses system default) |
| `fontSize`         | `48`            | Font size for key text |
| `titleFontSize`    | `16`            | Font size for title text |
| `rowGap`           | `8`             | Gap between icon row and title row (px) |
| `titleMaxSize`     | `72`            | Max title length shown |
| `showTitles`       | `true`          | Whether to show title rows |
| `bgColor`          | `{ red = 0, green = 0, blue = 0, alpha = 0.72 }` | Hint badge background color |
| `dimmedBgAlpha`    | `0.22`          | Background alpha for dimmed (input-mismatched) hints |
| `textColor`        | `{ red = 1, green = 1, blue = 1, alpha = 1 }` | Key text color |
| `dimmedTextColor`  | `{ red = 1, green = 1, blue = 1, alpha = 0.35 }` | Key text color for dimmed hints |
| `titleTextColor`   | `{ red = 0.84, green = 0.84, blue = 0.86, alpha = 1 }` | Title text color |
| `dimmedTitleTextColor` | `{ red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 }` | Title text color for dimmed hints |
| `keyHighlightColor` | `{ red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 }` | Highlight color for already-typed key prefix |
| `iconAlpha`        | `0.95`          | App icon opacity |
| `dimmedIconAlpha`  | `0.48`          | App icon opacity for dimmed hints |
| `bumpMove`         | `90`            | Offset distance when hint badges overlap (px) |
| `showPreviewForOccluded` | `true`     | Whether to show preview images for fully occluded windows |
| `appPrefixOverrides` | `nil`         | Override leading prefixes via rule array (`window:title()` `glob` support, 1-2 char prefixes) |
| `occlusionSamplingEnabled` | `true`   | Whether occlusion sampling is dynamically adjusted |
| `occlusionSamplingBaseWidth` | `1920`  | Base window width for occlusion sampling (px) |
| `occlusionSamplingBaseHeight` | `1080` | Base window height for occlusion sampling (px) |
| `occlusionSamplingMinCols` | `4`       | Minimum sampling columns for occlusion check |
| `occlusionSamplingMinRows` | `4`       | Minimum sampling rows for occlusion check |
| `occlusionSamplingMaxCols` | `8`       | Maximum sampling columns for occlusion check |
| `occlusionSamplingMaxRows` | `8`       | Maximum sampling rows for occlusion check |
| `previewWidth`     | `140`           | Preview image width for occluded windows (px) |
| `previewPadding`   | `6`             | Top padding above preview image (px) |
| `occludedScale`    | `0.65`          | Scale factor for occluded hint badges |
| `occludedBgAlpha`  | `0.50`          | Background alpha for occluded hint badges |
| `occludedIconAlpha` | `0.65`         | App icon opacity for occluded hint badges |
| `occludedPreviewAlpha` | `0.65`      | Preview image opacity for occluded hint badges |
| `activeOverlayColor` | `{ red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 }` | Fill color for active window overlay |
| `activeOverlayBorderColor` | `{ red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 }` | Border color for active window overlay |
| `activeOverlayBorderWidth` | `10`     | Border width for active window overlay (px) |
| `activeOverlayCornerRadius` | `10`    | Corner radius for active window overlay (px) |
| `hintOverlayColor` | `{ red = 0.40, green = 0.68, blue = 0.98, alpha = 0.38 }` | Fill color for front hint badge overlays |
| `hintOverlayBorderColor` | `{ red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 }` | Border color for front hint badge overlays |
| `dimmedHintOverlayBorderColor` | `{ red = 0.55, green = 0.55, blue = 0.55, alpha = 0.35 }` | Overlay border color for hints excluded by current key input |
| `hintOverlayBorderWidth` | `4`        | Border width for front hint badge overlays (px) |
| `hintOverlayCornerRadius` | `12`      | Corner radius for front hint badge overlays (px) |
| `dockBottomMargin` | `24`            | Bottom margin from screen edge for occluded-hint dock (px) |
| `dockItemGap`      | `10`            | Item gap inside occluded-hint dock (px) |
| `focusBackKey`     | `nil`           | Key to trigger Focus Back equivalent while Window Hints is visible (`focus_back` must be enabled) |
| `directionKeys`    | `nil`           | 8-direction navigation keys while Window Hints is visible  |
| `cardinalOverlapTieThresholdPx` | `960` | Tie threshold (px) for orthogonal-overlap differences in cardinal directional navigation |
| `debugDirectionalNavigation` | `false` | Emit directional candidate scoring logs for `directionKeys` debugging |
| `swapWindowFrameSelectModifiers` | `nil` | Modifier keys for swapping frames between focused and target windows when selecting hints or using `focusBackKey` / `directionKeys` |
| `onSelect`         | `nil`           | Callback on window selection |
| `onError`          | `nil`           | Callback on error |
| `centerCursor`     | `false`         | Move cursor to window center after selection |
| `centerCursorOnStart` | `false`      | Move cursor to active window center at startup |

`focusHistory` is an internal injected option and is not intended for direct user configuration.

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
- If no rule matches, characters in the app name are checked from left to right and the first available one in `hintChars` is used (if already used, the next candidate is tried); if none match, it falls back to `hintChars[1]`
- Invalid `prefix` values (characters not in `hintChars`, 3+ chars, etc.) raise errors

For implementation defaults and internal options, see `DEFAULT_CONFIG` in `window_hints.lua`.

### Navigation During Window Hints

- `focusBackKey` and `directionKeys` are active only while hints are shown
- `focusBackKey` works only when `focus_back` is enabled
- If these keys conflict with `hintChars`, the conflicting hint chars are removed and navigation keys take priority
- Fully occluded windows are excluded from directional navigation candidates
- Cardinal directions prefer larger orthogonal overlap first; when the overlap difference is within `cardinalOverlapTieThresholdPx`, it is treated as a tie and falls through to primary-axis edge gap, frontmost order, orthogonal offset, and finally the previously active window
- Diagonal directions prefer the smallest sum of two axis edge gaps, then frontmost order, center distance, and finally the previously active window

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

## Development

With the setup above, editing files under `Jinrai.spoon/` and running `Reload Config` in Hammerspoon reflects changes immediately.

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
