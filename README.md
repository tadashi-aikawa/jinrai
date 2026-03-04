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

### Prerequisites

If you do not have Hammerspoon yet:

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

Then install SpoonInstall:

```bash
mkdir -p ~/.hammerspoon/Spoons
curl -L https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip -o /tmp/SpoonInstall.spoon.zip
unzip -o /tmp/SpoonInstall.spoon.zip -d ~/.hammerspoon/Spoons
```

### Install via SpoonInstall (Recommended)

Add this to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.jinrai = {
  url = "https://github.com/tadashi-aikawa/jinrai",
  desc = "JINRAI Spoon repository",
  branch = "spoons",
}

spoon.SpoonInstall:andUse("Jinrai", {
  repo = "jinrai",
  fn = function(jinrai)
    jinrai:setup({
      focus_border = {},
      window_hints = {},
      focus_back = {},
    })
  end,
})
```

If you omit `focus_border`, `window_hints`, or `focus_back`, that module is disabled.

To update an already installed Spoon:

```lua
spoon.SpoonInstall:updateRepo("jinrai")
spoon.SpoonInstall:installSpoonFromRepo("Jinrai", "jinrai")
hs.reload()
```

### Install from source (for development)

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
    visual = {
      border = {
        width = 10,
        color = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
      },
      outline = {
        width = 2,
        color = { red = 0, green = 0, blue = 0, alpha = 0.70 },
      },
      cornerRadius = 10,
    },
    animation = {
      duration = 0.5,
      fadeSteps = 18,
    },
    window = {
      minSize = 480,
    },
  },
  window_hints = {
    hotkey = {
      modifiers = { "alt" },
      key = "f20",
    },
    hint = {
      chars = { "A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M" },
      prefixOverrides = {
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
    },
    navigation = {
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
      directHotkeys = {
        modifiers = { "ctrl", "alt" },
        keys = {
          left = "h",
          down = "j",
          up = "k",
          right = "l",
          upLeft = "y",
          upRight = "u",
          downLeft = "b",
          downRight = "n",
        },
      },
      swapSelectModifiers = { "shift" },
    },
    ui = {
      icon = { size = 72 },
      text = { titleMaxSize = 72 },
    },
    behavior = {
      centerCursor = true,
      onError = function(err)
        hs.alert.show("Window Hints error: " .. tostring(err), 3)
      end,
    },
  },
  focus_back = {
    hotkey = {
      modifiers = { "option" },
      key = "w",
    },
    behavior = {
      centerCursor = true,
    },
  },
})
```

## Focus Border Options

Complete sample including all options (default values):

```lua
focus_border = {
  visual = {
    border = {
      width = 10, -- Main border width (px)
      color = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 }, -- Main border color
    },
    outline = {
      width = 2, -- Outer outline width (px)
      color = { red = 0, green = 0, blue = 0, alpha = 0.70 }, -- Outer outline color
    },
    cornerRadius = 10, -- Corner radius (px)
  },
  animation = {
    duration = 0.5, -- Fade-out duration (seconds)
    fadeSteps = 18, -- Number of fade-out steps
  },
  window = {
    minSize = 480, -- Minimum window size to display (px)
  },
}
```

## Window Hints Options

Complete sample including all options (default values):

```lua
window_hints = {
  hotkey = {
    modifiers = { "alt" }, -- Hotkey modifiers to show hints
    key = "f20",            -- Hotkey key to show hints
  },
  hint = {
    chars = { "A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M" }, -- Hint character set
    prefixOverrides = nil, -- Prefix override rule array
  },
  ui = {
    icon = {
      size = 72,          -- Icon size (px)
      alpha = 0.95,       -- Icon opacity
      dimmedAlpha = 0.30, -- Icon opacity for dimmed hints
    },
    keyBox = {
      size = 72,              -- Key box height (px)
      minWidth = 72,          -- Key box minimum width (px)
      horizontalPadding = 10, -- Key box left/right padding (px)
      gap = 0,                -- Gap between icon and key box (px)
    },
    text = {
      fontName = nil,      -- Font name (nil for system default)
      keyFontSize = 48,    -- Key font size
      titleFontSize = 16,  -- Title font size
      rowGap = 8,          -- Gap between icon row and title row (px)
      titleMaxSize = 72,   -- Max title length
      showTitles = true,   -- Whether title row is shown
      keyColor = { red = 1, green = 1, blue = 1, alpha = 1 }, -- Key text color
      keyDimmedColor = { red = 0.85, green = 0.85, blue = 0.88, alpha = 0.28 }, -- Key color for dimmed hints
      titleColor = { red = 0.90, green = 0.92, blue = 0.96, alpha = 1.00 }, -- Title text color
      titleDimmedColor = { red = 0.90, green = 0.92, blue = 0.96, alpha = 0.30 }, -- Title color for dimmed hints
      keyHighlightColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 }, -- Highlight color for typed prefix
    },
    badge = {
      padding = 12, -- Inner badge padding (px)
      bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 }, -- Badge background color
      dimmedBgAlpha = 0.14, -- Badge background alpha for dimmed hints
      bumpMove = 90, -- Offset distance for overlapping hints (px)
    },
  },
  overlay = {
    active = {
      fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 }, -- Active window overlay fill
      borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 }, -- Active window overlay border
      borderWidth = 13, -- Active window overlay border width (px)
      cornerRadius = 10, -- Active window overlay corner radius (px)
    },
    hint = {
      fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.56 }, -- Front hint overlay fill
      borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 }, -- Front hint overlay border
      dimmedBorderColor = { red = 0.45, green = 0.45, blue = 0.48, alpha = 0.30 }, -- Front hint overlay border for dimmed hints
      borderWidth = 6, -- Front hint overlay border width (px)
      cornerRadius = 12, -- Front hint overlay corner radius (px)
    },
  },
  occlusion = {
    sampling = {
      enabled = true,    -- Whether occlusion sampling is dynamic
      baseWidth = 1920,  -- Base width for sampling scale (px)
      baseHeight = 1080, -- Base height for sampling scale (px)
      minCols = 4,       -- Minimum sampling columns
      minRows = 4,       -- Minimum sampling rows
      maxCols = 8,       -- Maximum sampling columns
      maxRows = 8,       -- Maximum sampling rows
    },
    preview = {
      enabled = true, -- Whether previews are shown for occluded windows
      width = 140,    -- Preview width (px)
      padding = 6,    -- Preview top padding (px)
      alpha = 0.46,   -- Preview opacity
    },
    hint = {
      scale = 0.65,   -- Scale factor for occluded hints
      bgAlpha = 0.32, -- Background alpha for occluded hints
      iconAlpha = 0.46, -- Icon opacity for occluded hints
    },
  },
  dock = {
    bottomMargin = 24, -- Bottom margin for occluded-hint dock (px)
    itemGap = 12,      -- Item gap in occluded-hint dock (px)
    windowBlend = {
      x = 0.0, -- Blend ratio to shift dock x toward each target window
      y = 0.0, -- Blend ratio to shift dock y toward each target window
    },
  },
  navigation = {
    focusBackKey = nil, -- Focus Back-equivalent key while hints are shown
    directionKeys = nil, -- Directional navigation keys while hints are shown
    directHotkeys = nil, -- Directional hotkeys without opening hints
    cardinalOverlapTieThresholdPx = 720, -- Tie threshold for cardinal direction scoring (px)
    debugDirectionalNavigation = false, -- Emit directional scoring debug logs
    swapSelectModifiers = nil, -- Modifiers to swap window frames when selecting
  },
  behavior = {
    onSelect = nil, -- Callback on window selection
    onError = nil,  -- Callback on errors
    centerCursor = false, -- Move cursor to selected window center
    centerCursorOnStart = false, -- Move cursor to active window center when hints start
  },
  internal = {
    focusHistory = nil, -- Internal injection only (normally do not set)
  },
}
```

Occlusion is determined by approximation using sample points inside each target window.
When `occlusion.sampling.enabled=true`, the sampling grid is dynamically adjusted within the range from `occlusion.sampling.min*` to `occlusion.sampling.max*`, based on `occlusion.sampling.baseWidth/baseHeight`.

### hint.prefixOverrides

`hint.prefixOverrides` lets you override the leading hint prefix per window.
Rules are evaluated from top to bottom, and the first matching rule is applied.

#### hint.prefixOverrides Definition

```lua
hint = {
  prefixOverrides = {
    {
      match = {
        bundleID = "md.obsidian",   -- optional
        titleGlob = "Minerva*",     -- optional (`window:title()` target, supports `*` and `?`)
      },
      prefix = "M",                 -- 1 or 2 chars. Each char must be included in hint.chars
    },
  },
}
```

#### hint.prefixOverrides Behavior

- Either `match.bundleID` or `match.titleGlob` is required
- `titleGlob` is case-sensitive
- Display key sets are automatically adjusted to stay prefix-free (for example, if `G` and `GC` conflict, they become `GA` and `GC`)
- If no rule matches, characters in the app name are checked from left to right and the first available one in `hint.chars` is used (if already used, the next candidate is tried); if none match, it falls back to `hint.chars[1]`
- Invalid `prefix` values (characters not in `hint.chars`, 3+ chars, etc.) raise errors

For implementation defaults and internal options, see `DEFAULT_CONFIG` in `window_hints_config.lua`.

### Navigation During Window Hints

- `navigation.focusBackKey` and `navigation.directionKeys` are active only while hints are shown
- `navigation.focusBackKey` works only when `focus_back` is enabled
- If these keys conflict with `hint.chars`, the conflicting hint chars are removed and navigation keys take priority
- Fully occluded windows are excluded from directional navigation candidates
- Cardinal directions prefer larger orthogonal overlap first; when the overlap difference is within `navigation.cardinalOverlapTieThresholdPx`, it is treated as a tie and falls through to primary-axis edge gap, frontmost order, orthogonal offset, and finally the previously active window
- Diagonal directions prefer the smallest sum of two axis edge gaps, then frontmost order, center distance, and finally the previously active window

### Direct Direction Hotkeys

`navigation.directHotkeys` lets you bind directional movement without showing hints.

```lua
navigation = {
  directHotkeys = {
    modifiers = { "ctrl", "alt" }, -- required
    keys = {                       -- optional; only specified directions are enabled
      left = "h",
      down = "j",
      up = "k",
      right = "l",
      upLeft = "y",
      upRight = "u",
      downLeft = "b",
      downRight = "n",
    },
  },
}
```

- Uses the same target selection rules as `navigation.directionKeys` (occlusion filtering and tie-break logic included)
- Moves focus immediately; Window Hints UI is not shown
- If `keys` is omitted or empty, direct-direction hotkeys are disabled
- In `modifiers`, `option` is accepted as an alias for `alt`

## Focus Back Options

Complete sample including all options (default values):

```lua
focus_back = {
  hotkey = {
    modifiers = { "option" }, -- Hotkey modifiers
    key = "w",                -- Hotkey (nil to disable)
  },
  urlEvent = {
    name = nil, -- URL scheme name (trigger via hammerspoon://<name>)
  },
  behavior = {
    centerCursor = false, -- Move cursor to window center after switching
  },
  stateSync = nil, -- State sync settings to compensate for missed events (see below)
  internal = {
    focusHistory = nil, -- Internal injection only (normally do not set)
  },
}
```

Pressing repeatedly lets you toggle between two windows.

### stateSync

`stateSync` helps prevent drift in `focus_back` history tracking.

In most cases, macOS focus notifications are sufficient. However, some apps do not emit reliable notifications when switching tabs, which can cause `focus_back` to jump to unexpected locations.
If you enable `stateSync`, JINRAI periodically checks window state and corrects history.

#### Examples where it helps

- Right after switching tabs, `focus_back` does not return to the tab you expected
- When moving between apps, `focus_back` targets are unstable

#### `stateSync` Definition

```lua
stateSync = {
  interval = 0.2,      -- Sync interval (seconds)
  targetApps = nil,    -- Array of target app names or bundle IDs (nil for all apps)
  historyScope = "window", -- History update scope ("window" or "application")
}
```

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

If you install from source with symlink, editing files under `Jinrai.spoon/` and running `Reload Config` in Hammerspoon reflects changes immediately.

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
