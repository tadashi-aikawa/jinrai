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
        - You can also click a hint to activate its window
    - Windows completely hidden by others (sampling-based approximation) are shown at the bottom in a dock-style layout with previews
        - Dock hints try to avoid overlapping front-window hints when possible
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

To update an already installed Spoon (run once in Hammerspoon Console):

```lua
spoon.SpoonInstall:updateRepo("jinrai")
spoon.SpoonInstall:installSpoonFromRepo("Jinrai", "jinrai")
hs.reload()
```

> [!WARNING]
> Do not put these three lines in `~/.hammerspoon/init.lua`. `hs.reload()` will rerun the same update block on each reload and cause a loop. Keep only persistent setup in `init.lua`, and run this block manually only when updating.

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
  macosNativeTabs = {
    -- See "macOS Native Tabs Options" below for the complete default schema and examples
  },
  focus_border = {
    -- See "Focus Border Options" below for the complete default schema and examples
  },
  window_hints = {
    -- See "Window Hints Options" below for the complete default schema and examples
  },
  focus_back = {
    -- See "Focus Back Options" below for the complete default schema and examples
  },
})
```

## macOS Native Tabs Options

`macosNativeTabs` configures compensation for apps that use macOS native tabs.

For target apps, each tab can have a different window ID. JINRAI hides tab-like candidates whose Space cannot be resolved in Window Hints and excludes tab moves within the same app from Focus Back history updates.

```lua
macosNativeTabs = {
  apps = { "com.example.terminal" }, -- Additional app names or bundle IDs
  stateSyncInterval = 0.5,           -- Focus Back state sync interval (default: 0.5)
}
```

Apps listed in `apps` are added to the built-in defaults. Set `macosNativeTabs = false` to disable this compensation entirely.

Default configuration:

- `com.mitchellh.ghostty`

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
    spaceSwitchDelay = 0.30, -- Extra delay only when focus moved to another Space (seconds)
  },
  window = {
    minSize = 480, -- Minimum window size to display (px)
  },
}
```

`spaceSwitchDelay` is applied only when focus moves to a window in a different macOS Space than the previously focused window. Focus changes within the same Space still render immediately.

## Window Hints Options

Note: this schema is breaking. Legacy keys such as `hint.keyBox`, `hint.text`, `hint.badge`, `hint.offSpaceBadge`, `hint.overlay`, `hint.onActiveWindow`, `activeWindow`, `navigation.focusBackKey`, `navigation.directionKeys`, `navigation.directHotkeys`, `navigation.spaceKeys`, and `behavior.centerCursor` are no longer supported.

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
    padding = 12, -- Hint card inner padding (px)
    collisionOffset = 90, -- Offset distance for overlapping hints (px)
    cornerRadius = 12, -- Hint card corner radius (px)
    occludedScale = 0.85, -- Scale factor for occluded hints
    highlight = {
      borderWidth = 6, -- Border width for hint highlight (px)
    },
    state = {
      normal = {
        bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 }, -- Hint card background
        highlight = {
          fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.56 }, -- Hint card highlight fill
          borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 }, -- Hint card highlight border
        },
      },
      dimmed = {
        bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.14 }, -- Hint card background for dimmed hints
        highlight = {
          borderColor = { red = 0.45, green = 0.45, blue = 0.48, alpha = 0.30 }, -- Hint card border for dimmed hints
        },
      },
      occluded = {
        bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.70 }, -- Hint card background for occluded hints
      },
      active = {
        bgColor = { red = 0.08, green = 0.05, blue = 0.03, alpha = 0.88 }, -- Hint card background on the active window
        highlight = {
          fillColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.56 }, -- Hint card highlight fill on the active window
          borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 }, -- Hint card highlight border on the active window
        },
      },
    },
    icon = {
      size = 72, -- Icon size (px)
      state = {
        normal = { alpha = 0.95 }, -- Icon opacity
        dimmed = { alpha = 0.30 }, -- Icon opacity for dimmed hints
        occluded = { alpha = 0.46 }, -- Icon opacity for occluded hints
        active = { alpha = 1.0 }, -- Icon opacity on the active window
      },
    },
    key = {
      size = 72, -- Key box height (px)
      minWidth = 72, -- Key box minimum width (px)
      horizontalPadding = 10, -- Key box left/right padding (px)
      gap = 0, -- Gap between icon and key box (px)
      fontName = nil, -- Key font name (nil for system default)
      fontSize = 48, -- Key font size
      keyHighlightColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 }, -- Highlight color for typed prefix
      state = {
        normal = {
          color = { red = 1, green = 1, blue = 1, alpha = 1 }, -- Key text color
        },
        dimmed = {
          color = { red = 0.85, green = 0.85, blue = 0.88, alpha = 0.28 }, -- Key text color for dimmed hints
        },
        occluded = {},
        active = {
          color = { red = 1.00, green = 0.93, blue = 0.86, alpha = 1.00 }, -- Key text color on the active window
        },
      },
    },
    title = {
      fontName = nil, -- Title font name (nil falls back to key.fontName)
      fontSize = 16, -- Title font size
      rowGap = 8, -- Gap between icon row and title row (px)
      maxSize = 72, -- Max title length
      show = true, -- Whether title row is shown
      state = {
        normal = {
          color = { red = 0.90, green = 0.92, blue = 0.96, alpha = 1.00 }, -- Title text color
        },
        dimmed = {
          color = { red = 0.90, green = 0.92, blue = 0.96, alpha = 0.30 }, -- Title text color for dimmed hints
        },
        occluded = {},
        active = {
          color = { red = 0.99, green = 0.90, blue = 0.78, alpha = 1.00 }, -- Title text color on the active window
        },
      },
    },
    spaceBadge = {
      enabled = true, -- Whether the Space badge is shown on other-Space candidates
      size = 32, -- Top-right badge diameter (px)
      state = {
        normal = {
          fillColor = { red = 0.34, green = 0.64, blue = 0.96, alpha = 0.56 }, -- Space badge fill (default/fallback)
          strokeColor = { red = 0.98, green = 0.99, blue = 1.00, alpha = 0.72 }, -- Space badge stroke (default/fallback)
          textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 }, -- Space badge text (default/fallback)
        },
        dimmed = {
          fillColor = { red = 0.34, green = 0.64, blue = 0.96, alpha = 0.28 }, -- Fill color for dimmed hints
          strokeColor = { red = 0.98, green = 0.99, blue = 1.00, alpha = 0.40 }, -- Stroke color for dimmed hints
          textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.35 }, -- Text color for dimmed hints
        },
        occluded = {},
        active = {
          fillColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.56 }, -- Badge fill on the active window
          strokeColor = { red = 1.00, green = 0.90, blue = 0.78, alpha = 0.72 }, -- Badge stroke on the active window
          textColor = { red = 1.0, green = 0.98, blue = 0.94, alpha = 0.92 }, -- Badge text on the active window
        },
      },
      spaceColors = { -- Per-Space color overrides (indexed by Space number). Omitted fields fall back to state.normal
        { fillColor = { ... }, strokeColor = { ... }, textColor = { ... } }, -- Space 1
        { fillColor = { ... }, strokeColor = { ... }, textColor = { ... } }, -- Space 2
        -- ...
      },
    },
  },
  focusedWindowHighlight = {
    fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 }, -- Focused window overlay fill
    borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 }, -- Focused window overlay border
    borderWidth = 13, -- Focused window overlay border width (px)
    cornerRadius = 10, -- Focused window overlay corner radius (px)
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
      enabled = true,        -- Whether previews are shown for occluded windows
      mode = "background",   -- Preview display mode ("background": full hint background / "below": below title)
      width = 140,           -- Preview width (px). In background mode, this is the thumbnail height for a full-screen-height window
      padding = 6,           -- Preview top padding (px, below mode only)
      alpha = 0.64,          -- Preview opacity
    },
  },
  dock = {
    bottomMargin = 96, -- Bottom margin for occluded-hint dock (px)
    itemGap = 12,      -- Item gap in occluded-hint dock (px)
    windowBlend = {
      x = 0.65, -- Blend ratio to shift dock x toward each target window
      y = 1, -- Blend ratio to shift dock y toward each target window
    },
  },
  navigation = {
    focusBack = {
      key = nil, -- Focus Back-equivalent key while hints are shown
    },
    direction = {
      hints = {
        keys = nil, -- Directional navigation keys while hints are shown
      },
      direct = {
        modifiers = nil, -- Directional hotkey modifiers without opening hints
        keys = nil, -- Directional hotkeys without opening hints
      },
      scoring = {
        cardinalOverlapTieThresholdPx = 720, -- Tie threshold for cardinal direction scoring (px)
        debug = false, -- Emit directional scoring debug logs
      },
    },
    spaces = {
      numbers = true, -- Press 1-9 during hints to switch Space
      prev = {
        key = nil, -- Key to move to the previous Space during hints
      },
      next = {
        key = nil, -- Key to move to the next Space during hints
      },
    },
  },
  behavior = {
    selection = {
      swapWindowFrame = {
        modifiers = nil, -- Modifiers to swap window frames when selecting
      },
    },
    cursor = {
      onSelect = true, -- Move cursor to selected window center
      onStart = true, -- Move cursor to active window center when hints start
    },
    candidates = {
      includeOtherSpaces = true, -- Include visible windows from other Spaces as candidates
      includeActiveWindow = true, -- Also show a hint on the currently active window
    },
    callbacks = {
      onSelect = nil, -- Callback on window selection
      onError = nil,  -- Callback on errors
    },
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

- Pressing the Window Hints hotkey again while hints are shown closes the hints
- `navigation.focusBack.key` and `navigation.direction.hints.keys` are active only while hints are shown
- `navigation.focusBack.key` works only when `focus_back` is enabled
- If these keys conflict with `hint.chars`, the conflicting hint chars are removed and navigation keys take priority
- Clicking a hint selects the same window as entering its hint key
- Clicking outside all hints while hints are shown closes the hints
- Fully occluded windows are excluded from directional navigation candidates
- Cardinal directions prefer larger orthogonal overlap first; when the overlap difference is within `navigation.direction.scoring.cardinalOverlapTieThresholdPx`, it is treated as a tie and falls through to primary-axis edge gap, frontmost order, orthogonal offset, and finally the previously active window
- Diagonal directions prefer the smallest sum of two axis edge gaps, then frontmost order, center distance, and finally the previously active window

### Direct Direction Hotkeys

`navigation.direction.direct` lets you bind directional movement without showing hints.

```lua
navigation = {
  direction = {
    direct = {
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
  },
}
```

- Uses the same target selection rules as `navigation.direction.hints.keys` (occlusion filtering and tie-break logic included)
- Moves focus immediately; Window Hints UI is not shown
- If `keys` is omitted or empty, direct-direction hotkeys are disabled
- In `modifiers`, `option` is accepted as an alias for `alt`

### navigation.spaces.numbers

When `navigation.spaces.numbers = true` (default), pressing `1`–`9` while hints are shown switches to the corresponding Space using `hs.spaces.gotoSpace()`. If the Space number does not exist, the key is consumed but nothing happens. Set to `false` to disable.

### navigation.spaces.prev.key / navigation.spaces.next.key

`navigation.spaces.prev.key` and `navigation.spaces.next.key` let you move to the previous or next Space while hints are shown. Setting either to a single character key (e.g. `","` / `"."`) closes hints first, then triggers the Space switch. The default is `nil` (disabled).

### behavior.candidates.includeOtherSpaces

If `behavior.candidates.includeOtherSpaces = true`, Window Hints include visible windows from other Spaces, not just the
current one. The default is `true`.

- Other-Space candidates are rendered in the same dock-style lane as occluded hints
- They are marked with a round badge in the top-right corner showing the Space number
- Badge colors change per Space number via `hint.spaceBadge.spaceColors` (5 preset colors included; out-of-range numbers fall back to default)
- Set `hint.spaceBadge.enabled = false` to hide the badge entirely
- You can customize the badge colors and size via `hint.spaceBadge`
- Selecting one calls `focus()` directly and lets macOS handle the Space switch
- Directional navigation during hints and `navigation.direction.direct` still target current-Space candidates only

### behavior.candidates.includeActiveWindow

If `behavior.candidates.includeActiveWindow = true`, Window Hints also show a hint on the currently focused window. The default is `true`.

- This keeps hint assignment more consistent when multiple windows of the same app are open
- Selecting the active window still runs `behavior.cursor.onSelect` if enabled
- The focused-window outline from `focusedWindowHighlight` remains visible
- You can override the active-window hint appearance via `hint.state.active`, `hint.icon.state.active`, `hint.key.state.active`, `hint.title.state.active`, and `hint.spaceBadge.state.active`
- Omitted fields in those `active` states fall back to each element's `normal` state

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
    cursor = {
      onSelect = true, -- Move cursor to window center after switching
    },
  },
  internal = {
    focusHistory = nil, -- Internal injection only (normally do not set)
  },
}
```

Pressing repeatedly lets you toggle between two windows.

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
