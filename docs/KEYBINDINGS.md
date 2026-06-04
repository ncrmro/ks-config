# Keybindings Documentation

> **Status**: Draft / Work in Progress
>
> **Purpose**: Unify keybinding configurations across all tools to create a cohesive, muscle-memory-friendly development environment that can be managed entirely through Nix.

---

## Table of Contents

1. [Overview & Philosophy](#overview--philosophy)
2. [Current State Analysis](#current-state-analysis)
3. [Hyprland (Wayland Compositor)](#hyprland-wayland-compositor)
4. [Ghostty (Terminal Emulator)](#ghostty-terminal-emulator)
5. [Zellij (Terminal Multiplexer)](#zellij-terminal-multiplexer)
6. [Helix (Text Editor)](#helix-text-editor)
7. [Browser (Firefox/Chrome with Vimium)](#browser-firefoxchrome-with-vimium)
8. [Git Aliases](#git-aliases)
9. [Hardware-Specific Configurations](#hardware-specific-configurations)
   - [Ultimate Hacking Keyboard (UHK)](#ultimate-hacking-keyboard-uhk)
   - [Framework Laptop](#framework-laptop)
   - [Portable Programmable Keyboard (Future)](#portable-programmable-keyboard-future)
   - [MacBook](#macbook)
   - [Hardware Translation Table](#hardware-translation-table)
10. [Keybinding Consistency Matrix](#keybinding-consistency-matrix)
11. [Nix Implementation Guide](#nix-implementation-guide)
12. [Migration Path](#migration-path)
13. [Quick Reference Cards](#quick-reference-cards)

---

## Overview & Philosophy

### Core Philosophy: Mouse-Free Workflow

**The primary goal of this keybinding configuration is to eliminate mouse usage entirely.** Every operation should be accessible via keyboard, optimized for speed, ergonomics, and muscle memory.

**Hardware-Aware Mouse Strategy**

Different hardware requires different mouse strategies:

**Laptops (Framework/MacBook):**
- **Built-in trackpad available** - use for mouse operations
- **Caps Lock**: Remapped to Ctrl (Linux) or Cmd (macOS) at OS level
- **No Caps Lock mouse mode needed** - trackpad is more efficient for laptop form factor
- **Tab navigation**: Caps Lock (Ctrl/Cmd) + W/E/R/C

**Dedicated Keyboards (UHK, portable programmable):**
- **No trackpad available** - mouse mode essential
- **Caps Lock Mouse Mode**: Caps Lock activates mouse mode for all mouse operations
  - `f` = left click
  - `s` = right click
  - `j/k/i/l` = cursor movement (left/down/up/right)
  - Additional controls (scroll, middle click, etc.) - TBD
- **Tab navigation**: Via Mod layer (sends Ctrl+PgUp/PgDn/T/W)

**Benefits**: Hardware-optimized strategies, no OS-level remapping needed for laptops, reduced hand movement, RSI prevention, increased speed

### Design Principles

**Modifier Key Strategy**
- `Super`: Hyprland window manager modifier (configured in Hyprland as `$mod = SUPER`)
  - **Physical key**: Alt key (swapped to Super via `altwin:swap_alt_win`)
  - On UHK: Fn2 + key sends Alt, which system interprets as Super due to swap
  - On Framework: Pressing Alt sends Super due to swap
  - On MacBook: Option key behavior (TBD)
- `Ctrl`: Application-level operations
- `Shift`: Modifications to base keybindings (e.g., reverse direction, new window vs current)

**Why the swap?**
- **Ergonomics**: Physical Alt key is in a more accessible thumb position than Super/Win key, making it ideal for frequent window management operations
- **Browser compatibility**: Physical Super + Left/Right sends Alt + Left/Right (after swap), which is the standard Chrome/Firefox back/forward shortcut
- **UHK integration**: Fn2 layer sends Alt codes, which become Super after swap - same muscle memory works
- **Summary**: Physical Alt = Hyprland window management, Physical Super = browser back/forward

**Consistency Patterns**
- **Spatial navigation**: `j k i l` (Vim-style, home row focused) across all tools
  - `j` = left, `k` = down, `i` = up, `l` = right
  - Stays on home row for maximum ergonomics
- **Tab navigation**: `w e r c` pattern (also home row)
  - `w` = previous tab, `e` = new tab, `r` = next tab, `c` = close tab
  - Mnemonic: W←E→R (left-to-right on keyboard), C for close
  - Used consistently across browser, terminal, and multiplexer
- Common actions: `q` = quit, `r` = reload (context-dependent)
- Mnemonics: Actions should be memorable and consistent
- Modal interactions: Submaps/modes for complex operations (resize, layout, etc.)

**Ergonomic Principles**
1. **Home Row Optimization**: Minimize finger travel from home row position
2. **Thumb Utilization**: Use UHK Fn2 thumb key for frequent modifiers
3. **Symmetrical Usage**: Balance left/right hand workload
4. **Layer Coherence**: Related functions grouped on same layer
5. **Reduced Strain**: Avoid awkward Ctrl+Shift+Alt combinations

**Goals**
1. **Zero mouse usage** for all development workflows
2. Minimize cognitive load when switching between tools
3. Reduce RSI through ergonomic key placement and programmable keyboard customization
4. Enable declarative configuration through Nix for reproducibility
5. **Maximize portability**: OS-level configuration allows any programmable keyboard to work identically

**Hardware-Aware Portability Strategy**

This configuration uses **hardware-specific optimizations** while maintaining **portable software configuration**:

### Hardware Types:

**Laptops (Framework/MacBook):**
- **Caps Lock → Ctrl/Cmd**: Configured at OS level (more ergonomic than Alt)
- **Tab Navigation**: Caps Lock + W/E/R/C (no OS remapping needed)
- **Mouse**: Use built-in trackpad
- **Why this works**: Caps Lock already remapped to Ctrl/Cmd, W/E/R/C send browser-standard shortcuts

**Dedicated Keyboards (UHK):**
- **Mod Layer**: Sends Ctrl+PgUp/PgDn/T/W for tab navigation
- **Caps Lock**: Mouse mode activation
- **Portability**: Same firmware works on desktop and with laptops

**Portable Programmable Keyboards (Future - Corne, Planck, etc.):**
- **Firmware Configuration**: Handles tab navigation and mouse mode
- **Send Same Codes**: Ctrl+PgUp/PgDn/T/W (matches UHK)
- **Portable**: Works identically to UHK, smaller form factor

### Software Configuration:

**Single Zellij Config Works Everywhere:**
```nix
keybinds = {
  normal = {
    # Laptop support (Caps Lock as Ctrl)
    "bind \"Ctrl Shift Tab\"" = { GoToPreviousTab = {}; };
    "bind \"Ctrl Tab\"" = { GoToNextTab = {}; };

    # UHK/portable keyboard support
    "bind \"Ctrl PageUp\"" = { GoToPreviousTab = {}; };
    "bind \"Ctrl PageDown\"" = { GoToNextTab = {}; };
  };
};
```

**Why This Approach?**
1. **Ergonomic**: Caps Lock more accessible than Alt on laptops
2. **No Complex Remapping**: Uses standard Ctrl/Cmd, no Hyprland key injection needed
3. **Hardware Optimized**: Each keyboard uses its strengths (trackpad vs mouse mode)
4. **Single Software Config**: One Zellij config supports all hardware
5. **Nix Module**: Centralized keybinding configuration in `home-manager/common/features/keybindings/`

---

## Current State Analysis

### What's Currently Configured

**Hyprland**
- Location: `/home/ncrmro/nixos-config/archive/home.nix:109-116`
- Status: ⚠️ Partial - Mouse bindings only
- Configured modifier: `$mod = SUPER`
- Physical key: Alt (swapped to Super via `altwin:swap_alt_win`)
- Known keybindings:
  - `Super+J` (physical Alt+J) = focus left pane
  - `Super+K` (physical Alt+K) = focus down pane
  - `Super+I` (physical Alt+I) = focus up pane
  - `Super+L` (physical Alt+L) = focus right pane
- Current config (legacy):
  ```nix
  "$mod" = "SUPER";
  bindm = [
    "$mod, mouse:272, movewindow"
    "$mod, mouse:273, resizewindow"
    "$mod ALT, mouse:272, resizewindow"
  ];
  ```

**Helix**
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/cli/helix.nix:43`
- Status: ⚠️ Minimal
- Current config:
  ```nix
  keys.normal = { ret = ":write"; };
  ```

**Git Aliases**
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/cli/git.nix`
- Status: ✅ Complete
- Aliases: `b`, `p`, `co`, `c`, `ci`, `a`, `st`

**Input Configuration**
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/desktop/default.nix:22-30`
- Status: ✅ Complete
- Config: Caps→Ctrl, Alt↔Win swap, mouse sensitivity

### What's Using Defaults

- **Zellij**: Using default keybindings (Ctrl+G leader key)
- **Ghostty**: No custom keybindings configured
- **Browser**: No Vimium configuration managed in Nix

### What's Missing

- Complete Hyprland keyboard bindings
- Ghostty terminal keybindings
- Zellij customization for workflow
- Enhanced Helix keybindings
- Browser extension configuration
- UHK layer programming
- Hardware-specific optimizations

### Reference Materials

- **Hyprland App Groups**: Spike at `/home/ncrmro/nixos-config/spikes/1757895719_hyprland_app_groups/`
  - Contains workspace layout suggestions
  - App group launch patterns
  - Suggested keybindings for group management

---

## Hyprland (Wayland Compositor)

### Documentation Reference
- Official docs: https://wiki.hypr.land/Configuring/Binds/
- **Current keybindings file**: `~/.config/hypr/hyprland.conf`

### Current Configuration
- Modifier: `$mod = SUPER`
- Physical key: Alt (swapped via `altwin:swap_alt_win`)

**Known Bindings:**
- `Super+J/K/I/L` (physical Alt+J/K/I/L): Window focus navigation
- `Alt+W` (physical Win+W): Close window ⚠️ **CONFLICTS with proposed tab navigation**

### Proposed Keybindings

#### Window Management

**Navigation:**
- `Super+J` (Alt+J): Focus left window
- `Super+K` (Alt+K): Focus down window
- `Super+I` (Alt+I): Focus up window
- `Super+L` (Alt+L): Focus right window

**Close Window:**
- **Current**: `Alt+W` (physical Win+W)
- **Recommended**: Change to `Super+Q` (physical Alt+Q) to free up Alt+W for tab navigation
  - Alternative: `Super+Shift+C` or `Super+X`

**Move, Resize, Float, Fullscreen:**
<!-- TBD -->

#### Workspace Navigation
<!-- 1-10, special workspaces, move windows between workspaces -->

#### Application Launching
<!-- Terminal, browser, app groups -->

#### Submaps/Modes
<!-- Resize mode, layout mode, move mode -->

#### Integration with App Groups
<!-- Launch development, communication, media, notes, monitoring groups -->

---

## Ghostty (Terminal Emulator)

### Documentation Reference
- Official docs: https://ghostty.org/docs/config/keybind
- Action reference: https://ghostty.org/docs/config/keybind/reference
- **List default keybindings**: Run `ghostty +list-keybinds --default`

### Current Configuration
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/keybindings.nix`
- **Strategy**: Ghostty acts as simple terminal emulator; Zellij handles all multiplexing (tabs AND panes)

### Tab Navigation
- `Ctrl+Shift+W` = Previous tab
- `Ctrl+Shift+E` = New tab (overrides default split binding)
- `Ctrl+Shift+R` = Next tab
- `Ctrl+Shift+C` = Close tab

### Pane/Split Management
**Status**: ❌ **DISABLED** - All pane management handled by Zellij

**Unbinded Ghostty Split Keybindings:**
- `Ctrl+Shift+O` - Would conflict with Zellij session mode (unbinded)
- `Ctrl+Alt+Up/Down/Left/Right` - Pane navigation (unbinded)

**Reason**: Avoiding conflicts with Zellij keybindings and maintaining single source of multiplexing control.

### Keybinding Conflicts Resolved

#### Conflict 1: Ctrl+Shift+O
- **Ghostty Default**: `new_split:right` (vertical split)
- **Zellij Custom**: Session mode (moved from Ctrl+O)
- **Resolution**: Ghostty split unbinded, Zellij session mode takes priority

#### Conflict 2: Ctrl+Shift+E
- **Ghostty Default**: `new_split:down` (horizontal split)
- **Ghostty Custom**: `new_tab` (our configuration)
- **Resolution**: Custom binding overrides default split behavior

### Proposed Keybindings

#### Tab/Pane Management
✅ **IMPLEMENTED** - Tab navigation configured, splits disabled (Zellij handles all panes)

#### Font Size Controls
<!-- Increase, decrease, reset -->

#### Quick Terminal Toggle
<!-- Global keybinding for dropdown terminal -->

#### Clipboard Operations
<!-- Copy, paste, selection modes -->

#### Configuration Syntax
```nix
# Example:
# keybind = trigger=action
# keybind = global:cmd+backquote=toggle_quick_terminal
# keybind = ctrl+shift+t=new_tab
```

---

## Zellij (Terminal Multiplexer)

### Documentation Reference
- Official docs: https://zellij.dev/documentation/keybindings.html
- Binding guide: https://zellij.dev/documentation/keybindings-binding.html
- **Default keybindings**: https://github.com/zellij-org/zellij/blob/main/zellij-utils/assets/config/default.kdl

### Current Configuration
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/cli/default.nix:107-114`
- Using defaults with Tokyo Night theme
- **Usage**: Runs inside Ghostty terminal

### Tab Navigation Integration

**Goal**: Use Zellij tabs (not Ghostty tabs) with UHK Mod layer keybindings (W/E/R/C pattern).

**Current Status:**
- ❌ UHK Mod+W/R/E/C sends Ctrl+PgUp/PgDn/T/W
- ❌ Zellij doesn't respond to these keys by default
- ✅ Can be configured with custom keybindings

### Proposed Keybindings

#### Tab Navigation (Primary Use Case)

**Option 1: Configure Zellij for Alt+W/E/R/C** (Recommended)

After reconfiguring UHK Mod layer to send Alt codes:

```nix
programs.zellij = {
  enable = true;
  enableZshIntegration = true;
  settings = {
    attach_to_session = true;
    theme = "tokyo-night-dark";

    keybinds = {
      normal = {
        # Tab navigation using Alt+W/E/R/C
        "bind \"Alt w\"" = { GoToPreviousTab = {}; };
        "bind \"Alt r\"" = { GoToNextTab = {}; };
        "bind \"Alt e\"" = { NewTab = {}; };
        "bind \"Alt c\"" = { CloseTab = {}; };
      };
    };
  };
};
```

**Option 2: Configure Zellij for Ctrl+PgUp/PgDn/T/W** (Keep current UHK)

```nix
programs.zellij = {
  enable = true;
  enableZshIntegration = true;
  settings = {
    attach_to_session = true;
    theme = "tokyo-night-dark";

    keybinds = {
      normal = {
        # Tab navigation using Ctrl+PgUp/PgDn/T/W (current UHK output)
        "bind \"Ctrl PageUp\"" = { GoToPreviousTab = {}; };
        "bind \"Ctrl PageDown\"" = { GoToNextTab = {}; };
        "bind \"Ctrl t\"" = { NewTab = {}; };
        "bind \"Ctrl w\"" = { CloseTab = {}; };
      };
    };
  };
};
```

#### Pane Navigation & Switching

Zellij provides multiple methods for pane navigation. For the fastest workflow, use the **Shared Keybindings** (Method 2) which work directly in normal mode without entering pane mode first.

**Method 1: Pane Mode (Modal Navigation)**

Enter pane mode to access full pane management:
- `Ctrl+P` - Enter pane mode
- Once in pane mode:
  - `h/j/k/l` or `←/↓/↑/→` - Move focus to pane in that direction
  - `p` - Cycle/toggle focus between panes (useful for quick two-pane switching)
  - `n` - Create new pane
  - `x` - Close current pane
  - `z` - Toggle fullscreen for current pane
  - `Esc` or `Enter` - Return to normal mode

**Method 2: Shared Keybindings (Fastest - Recommended)**

These work directly in normal mode without entering pane mode first:

**Directional Navigation:**
- `Alt+h` or `Alt+←` - Focus pane to the left
- `Alt+j` or `Alt+↓` - Focus pane below
- `Alt+k` or `Alt+↑` - Focus pane above
- `Alt+l` or `Alt+→` - Focus pane to the right

**Why this is fastest:**
- No mode switching required (always available in normal mode)
- Single keystroke navigation
- Ergonomic for UHK users: Alt key (Fn2 on UHK) + home row keys (h/j/k/l)
- Works consistently with Vim-style navigation muscle memory

**Method 3: Quick Two-Pane Toggle**

For rapid switching between exactly two panes:

**Option A: Directional Toggle**
- Horizontal splits (side-by-side): `Alt+h` and `Alt+l` (or `Alt+←` / `Alt+→`)
- Vertical splits (top-bottom): `Alt+k` and `Alt+j` (or `Alt+↑` / `Alt+↓`)

**Option B: Cycling**
- `Ctrl+P` then `p` - Cycle between panes
- Each press of `p` moves to next pane
- With two panes, this toggles between them

**Method Comparison:**

| Method | Keystrokes | Mode Switch | Best For |
|--------|------------|-------------|----------|
| Alt+h/j/k/l | 1 | No | Quick directional navigation (recommended) |
| Ctrl+P then p | 2 | Yes | Cycling through 3+ panes |
| Ctrl+P then h/j/k/l | 2 | Yes | When already in pane mode for management |

**Ergonomic Recommendations for UHK Users:**

1. **Primary Navigation**: Use `Alt+h/j/k/l` (shared keybindings)
   - UHK: Fn2 (thumb) + h/j/k/l
   - Stays on home row, minimal finger movement
   - No mode switching overhead

2. **Two-Pane Workflow**:
   - Editing code in left pane, running tests in right pane
   - `Alt+h` (focus left/code), `Alt+l` (focus right/tests)
   - Fast iteration: edit → save → `Alt+l` → check output → `Alt+h` → continue editing

3. **Multi-Pane Layouts**:
   - Use directional navigation (`Alt+h/j/k/l`) when you know the pane position
   - Use cycling (`Ctrl+P` then `p`) when exploring unfamiliar layouts

**Integration with Hyprland:**

Important distinction between window and pane navigation:
- **Hyprland** (window manager): `Super+J/K/I/L` (physical Alt+JKIL after swap) - Navigate between Ghostty windows
- **Zellij** (inside terminal): `Alt+h/j/k/l` - Navigate between panes within a single Ghostty window
- Different modifiers prevent conflicts: Super for windows, Alt for panes

#### Session Management

<!-- Attach, detach, sessions -->

#### Layout Management

<!-- Switch layouts, custom layouts -->

#### Mode Switching

Default Zellij modes:
- Normal (Ctrl+G to enter mode)
- Pane mode (Ctrl+G → p)
- Tab mode (Ctrl+G → t)
- Resize mode (Ctrl+G → r)
- Locked mode (Ctrl+G → g)

#### Integration with Ghostty

**Strategy**: Use Zellij tabs, NOT Ghostty tabs
- Ghostty acts as simple terminal emulator
- Zellij provides all multiplexing (tabs, panes, sessions)
- Alt+W/E/R/C controls Zellij tabs
- Hyprland Super+JKIL navigates Ghostty windows (not Zellij panes)

---

## Helix (Text Editor)

### Documentation Reference
- Official keymap docs: https://docs.helix-editor.com/keymap.html
- View in editor: Run `:help keymap` inside Helix

### Current Configuration
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/cli/helix.nix:43`
- Current: `Return` → `:write`

### Proposed Keybindings

#### Normal Mode Enhancements
<!-- Custom normal mode bindings -->

#### Markdown Integration
- `F6`: Render Markdown to HTML and preview in browser
  - **Mechanism**: `:pipe helix-preview-markdown`
  - **Tools**: Uses `pandoc` for rendering and `xdg-open` for browser preview
  - **Bonus**: Copies the file URL to clipboard

#### LSP Operations
<!-- Go-to-definition, hover, rename, code actions -->

#### File Navigation
<!-- File picker, buffer switcher, symbol search -->

#### Multi-Cursor Workflows
<!-- Selection expansion, multiple cursors -->

#### Integration Workflows
<!-- Terminal spawning, git operations -->

---

## Browser (Firefox/Chrome with Vimium)

### Extension Reference
- Vimium: https://github.com/philc/vimium
- Vimium C: https://github.com/gdh1995/vimium-c

### Current Configuration
- Status: Manual installation only
- **UHK Tab Navigation**: ✅ Works (Ctrl+PgUp/PgDn/T/W are browser standards)
- **Framework**: ❌ Currently uses Win+number (not desired)

### Tab Navigation Integration

**Goal**: Consistent W/E/R/C pattern across browser, terminal, and multiplexer.

**Current UHK Behavior:**
- Mod+W (Ctrl+PgUp) = Previous tab ✅
- Mod+E (Ctrl+T) = New tab ✅
- Mod+R (Ctrl+PgDn) = Next tab ✅
- Mod+C (Ctrl+W) = Close tab ✅

**Future Strategy (when switching to Alt+W/E/R/C):**

**Option 1: Browser Extension (Vimium)**
Configure custom mappings in Vimium:
```
map <a-w> previousTab
map <a-r> nextTab
map <a-e> createTab
map <a-c> removeTab
```

**Option 2: Browser Shortcuts (Firefox)**
Configure in `about:config` or via Home Manager

**Option 3: Keep Ctrl+PgUp/PgDn/T/W**
If UHK stays with current config, browser already works. No changes needed.

### Proposed Keybindings

#### Navigation
- `j` / `k` = Scroll down/up
- `gg` / `G` = Scroll to top/bottom
- `f` / `F` = Link hints (open in current/new tab)
- `H` / `L` = History back/forward (Vimium)

#### Browser Back/Forward (Standard Shortcuts)
With `altwin:swap_alt_win` enabled, standard browser navigation works naturally:
- **Physical Super + Left Arrow** → sends `Alt + Left` → Browser back
- **Physical Super + Right Arrow** → sends `Alt + Right` → Browser forward

This is ergonomically nice because:
- Physical Alt (thumb position) is reserved for frequent Hyprland window management
- Physical Super (less accessible) is used for occasional browser navigation
- No UHK macros needed - just press physical Super + arrow keys directly

#### Tab Management (W/E/R/C Pattern)
**Current (UHK works already):**
- `Ctrl+PgUp` (`Alt+W` after reconfiguration) = Previous tab
- `Ctrl+T` (`Alt+E` after reconfiguration) = New tab
- `Ctrl+PgDn` (`Alt+R` after reconfiguration) = Next tab
- `Ctrl+W` (`Alt+C` after reconfiguration) = Close tab

**Vimium defaults (can coexist):**
- `J` = Previous tab
- `t` = New tab
- `K` = Next tab
- `x` = Close tab

#### Search
- `/` = Search on page
- `n` / `N` = Next/previous search result

#### Custom Mappings

For consistency with other tools, configure Vimium to use:
- Alt+W/E/R/C for tab navigation (matches Zellij)
- Keep standard Vimium bindings (J/K/t/x) as alternatives

### Nix Configuration Strategy

**Vimium Configuration Export:**
1. Configure Vimium settings in browser
2. Export settings to JSON
3. Store in `/home-manager/common/features/browser/vimium/config.json`
4. Document import process for new machines
5. Track in git for reproducibility

**Note**: Browser extensions can't be fully configured via Nix, but settings can be version-controlled and imported manually.

---

## Git Aliases

### Current Configuration
- Location: `/home/ncrmro/nixos-config/home-manager/common/features/cli/git.nix`

```nix
alias = {
  b = "branch";
  p = "pull";
  co = "checkout";
  c = "commit";
  ci = "commit -a";
  a = "add";
  st = "status -sb";
};
```

### Proposed Additions
<!-- Additional workflow aliases, integration patterns -->

---

## Tab Navigation Across Tools

### Universal Tab Navigation Standards

Most applications support these browser-standard shortcuts for tab navigation:

**Primary Shortcuts:**
- `Ctrl+PgUp` - Previous tab
- `Ctrl+PgDn` - Next tab
- `Ctrl+T` - New tab
- `Ctrl+W` - Close tab

**Alternative (also browser-standard):**
- `Ctrl+Shift+Tab` - Previous tab
- `Ctrl+Tab` - Next tab

Both sets work in modern browsers (Firefox, Chrome) and can be configured in Zellij.

### Hardware-Specific Access

#### Framework Laptop

**PgUp/PgDn Access:**
- `Fn + Arrow Up` = PgUp
- `Fn + Arrow Down` = PgDn

**Tab Navigation:**
- `Fn + Ctrl + Arrow Up` = Ctrl+PgUp (previous tab)
- `Fn + Ctrl + Arrow Down` = Ctrl+PgDn (next tab)
- `Ctrl + T` = New tab
- `Ctrl + W` = Close tab

**Alternative (no Fn key needed):**
- `Ctrl + Shift + Tab` = Previous tab
- `Ctrl + Tab` = Next tab

Both methods work - use whichever feels more natural.

#### UHK (Desktop/Workstation)

**Mod Layer provides direct access:**
- `Mod + W` → Sends `Ctrl+PgUp` (previous tab)
- `Mod + E` → Sends `Ctrl+T` (new tab)
- `Mod + R` → Sends `Ctrl+PgDn` (next tab)
- `Mod + C` → Sends `Ctrl+W` (close tab)

**Benefits:**
- No Fn key needed
- Home row access (W/E/R/C)
- Works identically in browser and Zellij

#### Portable Programmable Keyboard (Future)

**Configure firmware to match UHK:**
- Same Mod layer mappings
- Sends Ctrl+PgUp/PgDn/T/W
- Portable muscle memory

### Application Configuration

#### Browser (Firefox/Chrome)

**Works out of the box** - no configuration needed:
- ✅ Ctrl+PgUp / Ctrl+PgDn - Navigate tabs
- ✅ Ctrl+Shift+Tab / Ctrl+Tab - Also works
- ✅ Ctrl+T - New tab
- ✅ Ctrl+W - Close tab

**UHK Mod layer works immediately** - all shortcuts are browser defaults.

**Framework** - both methods work:
- Fn+Ctrl+Arrow = Ctrl+PgUp/PgDn
- Ctrl+Tab / Ctrl+Shift+Tab

#### Zellij (Terminal Multiplexer)

**Requires configuration** to support tab navigation shortcuts.

**Configuration location**: `home-manager/common/features/keybindings/zellij.nix`

```nix
programs.zellij = {
  enable = true;
  enableZshIntegration = true;
  settings = {
    attach_to_session = true;
    theme = "tokyo-night-dark";

    keybinds = {
      normal = {
        # UHK Mod layer support (Ctrl+PgUp/PgDn)
        "bind \"Ctrl PageUp\"" = { GoToPreviousTab = {}; };
        "bind \"Ctrl PageDown\"" = { GoToNextTab = {}; };

        # Framework alternative (Ctrl+Tab) - also works on all keyboards
        "bind \"Ctrl Shift Tab\"" = { GoToPreviousTab = {}; };
        "bind \"Ctrl Tab\"" = { GoToNextTab = {}; };

        # Home-row alternative for Framework laptop (no Fn juggling)
        "bind \"Alt [\"" = { GoToPreviousTab = {}; };
        "bind \"Alt ]\"" = { GoToNextTab = {}; };

        # New tab (works on all keyboards)
        "bind \"Ctrl t\"" = { NewTab = {}; };

        # Close tab (works on all keyboards)
        "bind \"Ctrl w\"" = { CloseTab = {}; };

        # Move tab left: Ctrl+Shift+PgUp
        # - UHK: Mod+Shift+W → Ctrl+Shift+PgUp
        # - Framework: Fn+Ctrl+Shift+Arrow Up → Ctrl+Shift+PgUp
        "bind \"Ctrl Shift PageUp\"" = { MoveTab = "Left"; };

        # Move tab right: Ctrl+Shift+PgDn
        # - UHK: Mod+Shift+R → Ctrl+Shift+PgDn
        # - Framework: Fn+Ctrl+Shift+Arrow Down → Ctrl+Shift+PgDn
        "bind \"Ctrl Shift PageDown\"" = { MoveTab = "Right"; };
      };
    };
  };
};
```

**Why both Ctrl+PgUp/PgDn AND Ctrl+Tab?**
- Ctrl+PgUp/PgDn: Works with UHK Mod layer, Framework Fn+Ctrl+Arrow
- Ctrl+Tab: Works on all keyboards without Fn key
- Having both gives flexibility across all hardware

#### Ghostty (Terminal Emulator)

**Strategy**: Disable Ghostty's native tab handling - Zellij manages all tabs.

**Configuration location**: `home-manager/common/features/keybindings/ghostty.nix`

```nix
programs.ghostty = {
  enable = true;
  settings = {
    # Disable Ghostty native tabs - Zellij handles all multiplexing
    keybind = [
      "ctrl+shift+t=unbind"
      "ctrl+shift+w=unbind"
      "ctrl+page_up=unbind"
      "ctrl+page_down=unbind"
      "ctrl+tab=unbind"
      "ctrl+shift+tab=unbind"
    ];
  };
};
```

**Why disable Ghostty tabs?**
1. Zellij provides superior tab/pane/session management
2. Avoids conflicts between Ghostty and Zellij tab shortcuts
3. Single interface (Zellij) = consistent, predictable behavior
4. Same keybindings work across all keyboards

### Workflow Examples

#### UHK at Desktop:

**Terminal (Zellij):**
1. Open terminal: Fn2+Return
2. Zellij starts automatically
3. New tab: `Mod+E` (Ctrl+T)
4. Navigate forward: `Mod+R` (Ctrl+PgDn)
5. Navigate backward: `Mod+W` (Ctrl+PgUp)
6. Close tab: `Mod+C` (Ctrl+W)

**Browser:**
- Same Mod+W/E/R/C shortcuts work immediately
- No configuration needed

#### Framework Laptop:

**Terminal (Zellij):**
1. Open terminal
2. Zellij starts automatically
3. New tab: `Ctrl+T`
4. Navigate forward: `Fn+Ctrl+Down` or `Ctrl+Tab`
5. Navigate backward: `Fn+Ctrl+Up` or `Ctrl+Shift+Tab`
6. Close tab: `Ctrl+W`

**Browser:**
- Same shortcuts work (both Fn+Ctrl+Arrow and Ctrl+Tab methods)

#### Framework + Portable Keyboard:

Same as UHK - Mod+W/E/R/C pattern works identically.

### Configuration Module Structure

All keybinding configurations are centralized in a single file:

**File**: `home-manager/common/features/keybindings.nix`

**Contains:**
- Zellij tab navigation keybindings (`programs.zellij.settings.keybinds`)
- Ghostty tab unbinding (`programs.ghostty.settings.keybind`)
- Future: Helix, browser, and other tool keybindings

**Imported by**: `home-manager/common/features/cli/default.nix`

**Separation of concerns:**
- `keybindings.nix`: ONLY keybinding configurations
- `cli/default.nix`: Program enable, theme, and other settings
- Zellij's `enable`, `enableZshIntegration`, `theme`, `attach_to_session` stay in cli/default.nix
- Ghostty's `enable` stays in its respective module

**Benefits:**
- Single file for all keybinding config
- Easy to find and update all keybindings
- Portable across machines
- Version controlled in Nix
- Clean separation from enable/theme settings

---

## Hardware-Specific Configurations

### Ultimate Hacking Keyboard (UHK)

#### Current Status
- Enabled in: `/home/ncrmro/nixos-config/hosts/ncrmro-laptop/default.nix:71`
- Enabled in: `/home/ncrmro/nixos-config/hosts/workstation/default.nix:54`
- Config: `keystone.hardware.uhk.enable = true;`

#### Layer Architecture

The UHK uses a layer system where each layer binds actions to keys. Layers are activated via dedicated keys, with Fn2 positioned under the right thumb for ergonomic access.

**Current Layer Configuration:**

##### Fn2 Layer (Hyprland Navigation)
**Position**: Right thumb key
**Purpose**: Ergonomic access to Hyprland window management

**Current Fn2 Mappings** (selectively configured, not blanket Alt modifier):
- `Fn2 + J` → sends `Alt+J` → system interprets as `Super+J` (due to `altwin:swap_alt_win`) → Hyprland: focus left pane
- `Fn2 + K` → sends `Alt+K` → system interprets as `Super+K` → Hyprland: focus down pane
- `Fn2 + I` → sends `Alt+I` → system interprets as `Super+I` → Hyprland: focus up pane
- `Fn2 + L` → sends `Alt+L` → system interprets as `Super+L` → Hyprland: focus right pane

**Note**: These are manually configured key mappings in UHK Agent, not a global "Fn2 = Alt modifier" setting.

**Why send Alt if Hyprland uses Super?**
- The `kb_options = "altwin:swap_alt_win"` setting swaps Alt and Super at the X11/Wayland input level
- UHK sends Alt codes → system swaps them to Super → Hyprland receives Super
- This allows using the ergonomically positioned Alt key for window management

##### Mod Layer (Arrow Keys + Tab Navigation)
**Purpose**: Vim-style arrow key navigation AND universal tab navigation

**Current Mappings**:

**Arrow Keys (JKIL):**
- `Mod + J` → Left Arrow
- `Mod + K` → Down Arrow
- `Mod + I` → Up Arrow
- `Mod + L` → Right Arrow

**Tab Navigation (WERC):**
- `Mod + W` → `Ctrl + PgUp` (Previous tab)
- `Mod + E` → `Ctrl + T` (New tab)
- `Mod + R` → `Ctrl + PgDn` (Next tab)
- `Mod + C` → `Ctrl + W` (Close tab)
- `Mod + Shift + W` → `Ctrl + Shift + PgUp` (Move tab left)
- `Mod + Shift + R` → `Ctrl + Shift + PgDn` (Move tab right)

**Browser Navigation (Mod + Super):**
- `Mod + Super + J` → `Alt + Left Arrow` (Browser back)
- `Mod + Super + L` → `Alt + Right Arrow` (Browser forward)

**Current Behavior:**
- ✅ **Browser (Chrome/Firefox)**: All tab commands work (Ctrl+PgUp/PgDn/T/W are standard)
- ✅ **Ghostty**: Tab navigation works (Ghostty responds to Ctrl+PgUp/PgDn/T)
- ❌ **Zellij**: Does NOT work (Zellij doesn't respond to Ctrl+PgUp/PgDn by default)
- ❌ **Close in Ghostty/Zellij**: Ctrl+W doesn't close tab/pane

**Desired Behavior:**
- Use **Zellij tabs** (not Ghostty tabs) for terminal multiplexing
- Mod+W/E/R/C should control Zellij tabs
- Framework laptop should replicate this pattern using Alt+W/E/R/C

**Portability Strategy:**

**⚠️ CONFLICT IDENTIFIED**: Hyprland currently uses `Alt+W` to close windows!

With `altwin:swap_alt_win` active:
- Physical `Alt+W` → System swaps to `Super+W` → Sent to applications/Hyprland
- Physical `Win+W` → System swaps to `Alt+W` → Triggers Hyprland close window

**Problem**: If we reconfigure for `Alt+W` tab navigation:
- User presses physical `Alt+W` for "previous tab"
- System swaps to `Super+W`
- If Hyprland has `Super+W` bound, it conflicts with application keybindings

**Solutions:**

**Option 1: Change Hyprland close window binding** (Most portable)
- Change Hyprland: `Alt+W` (close window) → `Super+Q` or `Super+Shift+C`
- Then reconfigure UHK Mod+W → `Alt+W` for tab navigation
- Physical `Alt+W` → swapped to `Super+W` → Goes to Zellij/Browser (no Hyprland conflict)
- ✅ Enables portable `Alt+W/E/R/C` pattern across all keyboards

**Option 2: Use different keys for tab navigation** (Alternative)
- Keep Hyprland `Alt+W` for close window
- Use different keys for tabs, e.g., `Alt+,/.` (comma/period) or `Alt+[/]`
- Less mnemonic but avoids conflict

**Option 3: Keep current Ctrl+PgUp/PgDn/T/W** (Works now, less portable)
- Keep UHK sending `Ctrl+PgUp/PgDn/T/W`
- No Hyprland conflicts (these keys not bound)
- Configure Zellij custom keybindings for `Ctrl+PgUp/PgDn/T/W`
- Framework requires different approach or additional key mapping layer
- ❌ Less portable across keyboards

**Recommendation**: Use **Option 1** - Change Hyprland close window to `Super+Q`, then use `Alt+W/E/R/C` for tabs universally.

##### Base Layer
- Standard QWERTY layout
- Possible home row mods (TBD)

##### Fn Layer
- Function keys (F1-F12)
- System controls

##### Fn3-Fn5 Layers
- Reserved for future expansion
- Potential uses:
  - Fn3: Development tools (IDE shortcuts, terminal operations)
  - Fn4: Media controls and system operations
  - Fn5: Application-specific bindings

#### Ergonomic Design Benefits

1. **Thumb Access**: Fn2 under right thumb eliminates pinky strain from holding Alt
2. **Home Row Navigation**: J, K, I, L keeps fingers on home row
3. **Consistent Patterns**: Same keys (JKIL) across Mod and Fn2 layers
4. **Reduced Movement**: All navigation reachable without leaving home position

#### UHK Agent Configuration

Configuration is managed through UHK Agent software (https://ultimatehackingkeyboard.github.io/agent/).

**Mapping Process**:
1. Open UHK Agent
2. Select Fn2 layer
3. Click key to configure (J, K, I, or L)
4. Set secondary role to: "Keystroke" → Select modifiers (Alt) → Select key
5. Save to keyboard

#### NixOS Integration

NixOS enables UHK support through hardware module:

```nix
keystone.hardware.uhk.enable = true;
```

This ensures proper USB permissions and udev rules for UHK Agent access. Keymaps are stored in UHK hardware memory and persist across systems.

---

### Framework Laptop

#### Current Configuration
- Host: `/home/ncrmro/nixos-config/hosts/ncrmro-laptop/default.nix`
- Monitor: BOE 0x0BCA (built-in display)
- Keyboard: UHK support enabled (for when external UHK is connected)
- Fingerprint reader: Enabled

#### Input Configuration
```nix
kb_options = "compose:caps,ctrl:nocaps,altwin:swap_alt_win";
```
- Caps Lock → Ctrl
- Caps Lock disabled (important for Caps Lock mouse mode)
- Alt ↔ Win swapped

#### Portable Keybinding Strategy

Since the Framework laptop lacks the UHK's ergonomic Fn2 thumb key, the same Hyprland operations are accessed via direct Alt key usage (which is swapped to Super):

**Hyprland Navigation** (matches UHK Fn2 layer exactly):
- Physical `Alt + J` → sends `Super+J` (due to swap) → Hyprland: focus left pane
- Physical `Alt + K` → sends `Super+K` → Hyprland: focus down pane
- Physical `Alt + I` → sends `Super+I` → Hyprland: focus up pane
- Physical `Alt + L` → sends `Super+L` → Hyprland: focus right pane

**Key Insight**: The muscle memory is identical between UHK and Framework:
- UHK: Thumb presses Fn2, fingers press JKIL → sends Alt+JKIL → swapped to Super+JKIL
- Framework: Thumb presses Alt, fingers press JKIL → sends Alt+JKIL → swapped to Super+JKIL
- **Same physical keys, same hand positions, same cognitive pattern**

#### Laptop-Specific Considerations

**Layout Differences**:
- No dedicated navigation cluster (Home/End/PgUp/PgDn)
- Function keys require Fn modifier (F1-F12)
- No numpad
- Trackpad available (but avoid for mouse-free workflow)

**Optimization Strategies**:
1. **Alt Key Accessibility**:
   - Alt is positioned for thumb access (similar ergonomics to UHK Fn2)
   - With `altwin:swap_alt_win`, this is optimized for the layout

2. **Caps Lock as Ctrl**:
   - Frees up Caps Lock for mouse mode activation
   - Makes Ctrl more accessible for app-level operations

3. **Function Row**:
   - Media controls: Fn+F1-F12
   - Brightness: Fn+F7/F8
   - Volume: Fn+F9/F10/F11

#### Power/Brightness Keys
```
Fn + F7 = Brightness down
Fn + F8 = Brightness up
Fn + F9 = Mute
Fn + F10 = Volume down
Fn + F11 = Volume up
Fn + F12 = Keyboard backlight toggle
```

#### Migration from UHK

When switching from UHK to built-in Framework keyboard:
1. All Hyprland navigation works identically (Alt+JKIL)
2. Arrow key navigation requires standard arrow keys (no Mod layer)
3. Function keys require Fn modifier
4. All other keybindings remain consistent

**Recommendation**: Keep UHK connected when at desk for optimal ergonomics; use Framework keyboard for portable scenarios with identical Hyprland muscle memory.

---

### Portable Programmable Keyboard (Future)

#### Overview

For travel scenarios with the Framework laptop (or other portable setup), a compact programmable keyboard provides:
- Ergonomic benefits of custom layout
- Portability (40-60% size)
- Same muscle memory as UHK
- QMK/ZMK firmware for deep customization

#### Recommended Keyboards

**Popular Options**:
- **Corne (40-42 keys)**: Split, ergonomic, highly portable
- **Planck (47-48 keys)**: Ortholinear, compact, classic
- **Preonic (60 keys)**: Planck with number row
- **Lily58**: Split, more keys than Corne
- **Kyria**: Split, ergonomic, thumb clusters

**Selection Criteria**:
1. QMK/ZMK firmware support (for custom key mappings)
2. Thumb cluster or thumb keys (for layer access)
3. Travel-friendly size (fits in laptop bag)
4. Split or compact ergonomic layout

#### Configuration Strategy

**Firmware Setup** (QMK/ZMK):
```c
// Example QMK layer configuration
// Layer 0 (Base): Standard QWERTY
// Layer 1 (Lower): Navigation layer accessed via thumb key

// Configure thumb key to act as layer toggle
// Configure Layer 1:
// - J → Alt+J (Hyprland focus left)
// - K → Alt+K (Hyprland focus down)
// - I → Alt+I (Hyprland focus up)
// - L → Alt+L (Hyprland focus right)
```

**Key Principle**:
- Keyboard firmware sends `Alt+JKIL` codes
- OS-level `altwin:swap_alt_win` swaps to `Super+JKIL`
- Hyprland receives `Super+JKIL` for navigation
- **Identical to UHK and Framework behavior**

#### Portability Benefits

1. **Same OS Configuration**: No Nix config changes needed
2. **Same Muscle Memory**: Thumb + JKIL pattern identical to UHK
3. **Compact Travel**: Fits in laptop bag alongside Framework
4. **Universal**: Works with any laptop (Framework, MacBook, etc.)
5. **Firmware Persistence**: Keyboard config stored in firmware, not OS

#### Migration Checklist

When configuring a new portable keyboard:
- [ ] Flash QMK/ZMK firmware
- [ ] Configure base layer (QWERTY or preferred)
- [ ] Configure lower/raise layer with thumb key access
- [ ] Map navigation layer: J/K/I/L → Alt+J/K/I/L
- [ ] Test with Hyprland (should work immediately due to OS swap)
- [ ] Configure additional layers (function keys, media controls)
- [ ] Save firmware configuration to version control

---

### MacBook

#### Current Configuration
- Home Manager: `/home/ncrmro/nixos-config/home-manager/ncrmro/ncrmro-macbook.nix`
- Home Manager: `/home/ncrmro/nixos-config/home-manager/ncrmro/unsup-macbook.nix`
- Status: Minimal user setup, no custom keybindings
- **Operating System**: macOS (not NixOS/Hyprland)

#### macOS-Specific Considerations

**Important**: MacBook runs **macOS**, not Hyprland. Therefore, Hyprland-specific keybindings don't apply.

**Window Management on macOS:**
- macOS uses native window management (Mission Control, Spaces)
- Alternative tiling window managers:
  - **Aerospace**: Tiling window manager inspired by i3
  - **Rectangle**: Window snapping tool
  - **Amethyst**: Tiling window manager
  - **yabai**: Advanced tiling window manager

**Keyboard Layout Differences:**
- **Command** key instead of Super/Win (primary modifier on macOS)
- **Option** key instead of Alt
- Touch Bar on some models (context-sensitive function keys)

#### Portable Keyboard with macOS

If using a programmable keyboard (QMK/ZMK) with MacBook:

**Option 1: macOS Window Manager**
- Configure window manager (Aerospace/yabai) to use Cmd+JKIL
- Program keyboard to send Cmd+JKIL (Command instead of Alt)
- Different firmware from Linux setup

**Option 2: System-Level Key Swap**
- Use Karabiner-Elements to swap Option↔Command
- Program keyboard to send Alt+JKIL (same as Linux)
- Alt codes get swapped to Command codes
- Similar to Linux `altwin:swap_alt_win` approach

**Recommendation**: Use Option 2 for consistency with Linux setups. This allows the same keyboard firmware to work across Linux and macOS.

#### Tools Applicable to macOS

These keybinding configurations work on macOS:
- **Ghostty**: Cross-platform terminal (same config)
- **Zellij**: Cross-platform multiplexer (same config)
- **Helix**: Cross-platform editor (same config)
- **Browser/Vimium**: Cross-platform (same config)
- **Git aliases**: Cross-platform (same config)

**Not Applicable**:
- Hyprland keybindings (Linux-only Wayland compositor)

#### Home Manager macOS Module

**Important**: Home Manager should be used on macOS to manage keybindings for maximum consistency across platforms.

**Home Manager can manage on macOS:**
- **Ghostty terminal**: Keybindings configured in `programs.ghostty` module
- **Zellij**: Keybindings configured in `programs.zellij.settings`
- **Helix editor**: Keybindings configured in `programs.helix.settings.keys`
- **Git**: Aliases and configuration
- **Shell**: Zsh/Bash configuration
- **Browser**: Vimium config can be exported and tracked

**Benefits of Home Manager on macOS:**
1. **Single source of truth**: Same Nix config for NixOS and macOS
2. **Version controlled**: All keybindings tracked in git
3. **Declarative**: Reproducible across machines
4. **Cross-platform**: Keybindings for Ghostty/Zellij/Helix identical on both systems

**macOS-Specific (Outside Home Manager):**
- Window management (Aerospace, yabai, Rectangle)
  - Configure separately to use Cmd+JKIL or Option+JKIL
  - Karabiner-Elements for key swapping (if desired)

**Strategy**: Use Home Manager for all tool-specific keybindings; use native macOS/third-party tools only for window management.

---

### Hardware Translation Table

This table shows how the same window management operations are performed across different hardware configurations:

| Action | UHK (NixOS) | Framework Built-in (NixOS) | Portable QMK/ZMK (NixOS) | MacBook (macOS) |
|--------|-------------|----------------------------|--------------------------|-----------------|
| **WM Focus Left** | Fn2 (thumb) + J → Alt+J → Super+J* | Alt + J → Super+J* | Lower (thumb) + J → Alt+J → Super+J* | Cmd + J† or Option+J via Karabiner |
| **WM Focus Down** | Fn2 (thumb) + K → Alt+K → Super+K* | Alt + K → Super+K* | Lower (thumb) + K → Alt+K → Super+K* | Cmd + K† or Option+K via Karabiner |
| **WM Focus Up** | Fn2 (thumb) + I → Alt+I → Super+I* | Alt + I → Super+I* | Lower (thumb) + I → Alt+I → Super+I* | Cmd + I† or Option+I via Karabiner |
| **WM Focus Right** | Fn2 (thumb) + L → Alt+L → Super+L* | Alt + L → Super+L* | Lower (thumb) + L → Alt+L → Super+L* | Cmd + L† or Option+L via Karabiner |
| **Previous Tab** | Mod + W → Ctrl+PgUp (current)‡ | Alt + W (recommended) | Mod + W → Alt+W | Cmd + W or Alt+W |
| **New Tab** | Mod + E → Ctrl+T (current)‡ | Alt + E (recommended) | Mod + E → Alt+E | Cmd + E or Alt+E |
| **Next Tab** | Mod + R → Ctrl+PgDn (current)‡ | Alt + R (recommended) | Mod + R → Alt+R | Cmd + R or Alt+R |
| **Close Tab** | Mod + C → Ctrl+W (current)‡ | Alt + C (recommended) | Mod + C → Alt+C | Cmd + C or Alt+C |
| **Move Tab Left** | Mod + Shift + W → Ctrl+Shift+PgUp | Fn+Ctrl+Shift+↑ | Mod + Shift + W → Ctrl+Shift+PgUp | — |
| **Move Tab Right** | Mod + Shift + R → Ctrl+Shift+PgDn | Fn+Ctrl+Shift+↓ | Mod + Shift + R → Ctrl+Shift+PgDn | — |
| **Browser Back** | Mod + Super + J → Alt+Left | Alt + Left | Mod + Super + J → Alt+Left | Cmd + Left or Cmd + [ |
| **Browser Forward** | Mod + Super + L → Alt+Right | Alt + Right | Mod + Super + L → Alt+Right | Cmd + Right or Cmd + ] |
| **Arrow Keys** | Mod + JKIL → ←↓↑→ | Standard arrows | Firmware layer → ←↓↑→ | Standard arrows |
| **Caps Lock Mouse Mode** | Remapped to Ctrl | Remapped to Ctrl | Remapped to Ctrl | TBD |
| **Configuration Method** | UHK Agent (GUI) | N/A (built-in) | QMK/ZMK firmware | N/A (built-in) |
| **OS** | NixOS + Hyprland | NixOS + Hyprland | NixOS + Hyprland | macOS + Aerospace/yabai |
| **Portability** | Desktop use | Always available | Travel with laptop | macOS only |

\* **NixOS/Linux**: All keyboards send Alt codes → `altwin:swap_alt_win` swaps to Super → Hyprland receives Super

† **macOS**: Requires macOS window manager (Aerospace, yabai, etc.) configured for Cmd+JKIL navigation

‡ **Tab Navigation - Current vs Recommended**:
- **Current UHK**: Mod layer sends Ctrl+PgUp/PgDn/T/W (works in browser, Ghostty, but NOT Zellij)
- **Recommended**: Reconfigure to send Alt+W/E/R/C for portability
  - UHK: Mod layer → Alt+W/E/R/C
  - Framework: Direct Alt+W/E/R/C
  - Portable keyboard: Firmware layer → Alt+W/E/R/C
  - Zellij, browser, all tools configured for Alt+W/E/R/C
- **Alternative**: Keep Ctrl+PgUp/PgDn/T/W, configure Zellij to respond (less portable)

**Key Insights:**
1. **OS-Level Swap is Universal**: The `altwin:swap_alt_win` setting makes ALL keyboards work identically for window management
2. **Firmware Strategy**: Configure any programmable keyboard to send Alt codes (for WM) and Alt+W/E/R/C (for tabs)
3. **Thumb Ergonomics**: UHK Fn2/Mod and QMK/ZMK layers both provide thumb access
4. **No OS Changes Needed**: Adding a new keyboard requires zero Nix/Hyprland configuration changes
5. **Muscle Memory**: Physical pattern is identical across all keyboards (thumb + home row keys)
6. **Tab Navigation Portability**: Alt+W/E/R/C pattern works identically across all keyboards and platforms

**Adding a New Programmable Keyboard:**
1. Flash firmware (UHK Agent, QMK, or ZMK)
2. Configure navigation layer:
   - Fn2/Lower + J/K/I/L → Alt+J/K/I/L (window management)
   - Mod + W/E/R/C → Alt+W/E/R/C (tab navigation)
3. Plug in keyboard
4. Everything works immediately (OS swap setting and Zellij config already configured)

---

## Keybinding Consistency Matrix

### Common Operations Across Tools

| Action | Hyprland | Ghostty | Zellij | Helix | Browser (Vimium) |
|--------|----------|---------|--------|-------|------------------|
| **Window Navigation (Hyprland Level)** |
| Focus Left Window | `Super+J`* | N/A | N/A | N/A | N/A |
| Focus Down Window | `Super+K`* | N/A | N/A | N/A | N/A |
| Focus Up Window | `Super+I`* | N/A | N/A | N/A | N/A |
| Focus Right Window | `Super+L`* | N/A | N/A | N/A | N/A |
| **Pane Navigation (Within Application)** |
| Focus/Move Left | N/A | ❌ Disabled | `Alt+h` or `Alt+←` | `h` | TBD |
| Focus/Move Down | N/A | ❌ Disabled | `Alt+j` or `Alt+↓` | `j` | `j` (scroll) |
| Focus/Move Up | N/A | ❌ Disabled | `Alt+k` or `Alt+↑` | `k` | `k` (scroll) |
| Focus/Move Right | N/A | ❌ Disabled | `Alt+l` or `Alt+→` | `l` | TBD |
| Pane Mode Navigation | N/A | ❌ Disabled | `Ctrl+P` then `h/j/k/l` | N/A | N/A |
| Cycle/Toggle Panes | N/A | ❌ Disabled | `Ctrl+P` then `p` | N/A | N/A |
| **Tab Navigation (W/E/R/C Pattern)** |
| Previous Tab | N/A | Not used† | `Alt+[` or `Ctrl+PgUp` or `Ctrl+Shift+Tab` | N/A | `Alt+W`‡ or `Ctrl+PgUp` or `J` |
| New Tab | N/A | Not used† | `Alt+E`‡ or `Ctrl+T` | N/A | `Alt+E`‡ or `Ctrl+T` or `t` |
| Next Tab | N/A | Not used† | `Alt+]` or `Ctrl+PgDn` or `Ctrl+Tab` | N/A | `Alt+R`‡ or `Ctrl+PgDn` or `K` |
| Close Tab | N/A | Not used† | `Alt+C`‡ or `Ctrl+W` | N/A | `Alt+C`‡ or `Ctrl+W` or `x` |
| Move Tab Left | N/A | Not used† | `Ctrl+Shift+PgUp` | N/A | N/A |
| Move Tab Right | N/A | Not used† | `Ctrl+Shift+PgDn` | N/A | N/A |
| **Window/Pane Management** |
| New Window/Pane | `Super+Return`* | TBD | `Ctrl+G → n` | `:vsplit` | N/A |
| Close Window/Pane | `Super+Q`* (recommended, currently `Alt+W`) | TBD | `Ctrl+G → x` | `:q` | N/A |
| **Common Actions** |
| Reload/Refresh | `Super+R`* | TBD | TBD | `:reload` | `r` |
| Search | TBD | TBD | TBD | `/` | `/` |
| Quit Application | `Super+Shift+Q`* | TBD | TBD | `:q` | TBD |
| Save | N/A | N/A | N/A | `Return` | N/A |
| **Special Functions** |
| Fullscreen | `Super+F`* | TBD | TBD | TBD | TBD |
| Floating Toggle | `Super+V`* | N/A | N/A | N/A | N/A |
| Workspace 1-10 | `Super+1-0`* | N/A | N/A | N/A | N/A |

\* **Physical key**: Press Alt (swapped to Super via `altwin:swap_alt_win`)
- On UHK: Fn2 (thumb) + key sends Alt, swapped to Super
- On Framework: Alt + key sends Alt, swapped to Super
- Both produce identical Super keycodes to Hyprland

† **Ghostty tabs not used**: Strategy is to use Zellij tabs (inside Ghostty), not Ghostty's native tab feature

‡ **Alt+W/E/R/C (Recommended)**: Future portable configuration
- UHK Mod layer reconfigured to send Alt codes instead of Ctrl+PgUp/PgDn/T/W
- Framework uses Alt keys directly
- All keyboards work identically
- Alternative: Keep current Ctrl+PgUp/PgDn/T/W (works now but less portable)

*TBD = To Be Defined in implementation*

---

## Common Workflows & Use Cases

This section demonstrates practical, real-world usage of the keybinding system, showing how different tools work together for common development tasks.

### Application Launching

**Quick Launch Keybindings:**
- **Browser**: `Alt+B` (UHK: Fn2+B) → Opens Chrome/Firefox
- **Terminal**: `Alt+Return` (UHK: Fn2+Return) → Opens Ghostty with Zellij
- Physical key: Alt (swapped to Super, so Hyprland receives Super+B and Super+Return)

### Terminal Workflow: Directory Navigation

**Opening and Navigating:**
1. Press `Alt+Return` to launch Ghostty terminal
2. Zellij starts automatically inside Ghostty
3. Use zoxide for fast directory navigation:
   - `z <fuzzy-match>` → Jump to matching directory
   - `zi` → Interactive fuzzy search

**Example:**
```bash
# Quick jump to project directory
z proj          # Jumps to ~/projects or ~/code/my-project

# Interactive selection
zi              # Shows list of frecent directories
```

**Why it's fast:** Muscle memory for `Alt+Return` → `z <partial-name>` → instant directory access

### Text Navigation Patterns

#### Universal Text Navigation (UHK Mod Layer)

Works everywhere: Terminal, browser inputs, text editors, chat apps

**UHK Mod Layer Text Navigation:**
- `Mod+F`: Jump forward one word
- `Mod+S`: Jump backward one word
- `Mod+J/K/I/L`: Arrow keys (left/down/up/right)

**What it sends:** [TBD - verify actual keycodes sent by UHK Mod layer]

**Use cases:**
- Editing command in terminal: `Mod+S` to jump back a word, fix typo
- Browser address bar: `Mod+F` to navigate through URL segments
- Form fields: Quick navigation without reaching for arrow keys

#### Helix Editor Navigation

**Character/Line Movement:**

| Key | Direction | Movement | Command |
|-----|-----------|----------|---------|
| `h`, `←` | Left | Move one character left | move_char_left |
| `j`, `↓` | Down | Move one visual line down | move_visual_line_down |
| `k`, `↑` | Up | Move one visual line up | move_visual_line_up |
| `l`, `→` | Right | Move one character right | move_char_right |

**Word Navigation:**

| Key | Movement | Command | Notes |
|-----|----------|---------|-------|
| `w` | Next word start | move_next_word_start | Stops at punctuation |
| `b` | Previous word start | move_prev_word_start | Stops at punctuation |
| `e` | Next word end | move_next_word_end | Stops at punctuation |
| `W` | Next WORD start | move_next_long_word_start | Skips punctuation |
| `B` | Previous WORD start | move_prev_long_word_start | Skips punctuation |
| `E` | Next WORD end | move_next_long_word_end | Skips punctuation |

**Line Navigation:**
- `Ctrl+A`: Jump to start of line (Emacs-style)
- `Ctrl+E`: Jump to end of line (Emacs-style)

**Difference: word vs WORD**
- `word`: Treats punctuation as boundaries
  - Example: `my-variable-name` is **5 words** (my, -, variable, -, name)
- `WORD`: Ignores punctuation, space-separated only
  - Example: `my-variable-name` is **1 WORD**

**Practical example:**
```javascript
const myVariableName = getUserData();
//    ^w  ^w      ^w    ^w  ^w  ^w   (6 words)
//    ^W           ^W    ^W           (3 WORDs)
```

### Complete Workflow Examples

#### Scenario 1: Starting a Coding Session

**Goal:** Open project, edit files, run development server

1. **Launch terminal**
   - Press: `Alt+Return`
   - Result: Ghostty opens with Zellij

2. **Navigate to project**
   - Type: `zi`
   - Select: `my-web-app` from interactive list
   - Result: `cd ~/projects/my-web-app`

3. **Open editor**
   - Type: `hx .`
   - Result: Helix opens in project directory

4. **Find file**
   - Press: `Space` (Helix command mode)
   - Press: `f` (file picker)
   - Type: `comp` (fuzzy match)
   - Select: `components/Header.tsx`

5. **Start editing**
   - Use `w/b/e` for word navigation
   - Use `Ctrl+A/E` for line start/end
   - Press `Return` to save

6. **Open new tab for dev server**
   - Press: `Alt+E` (new Zellij tab)
   - Type: `npm run dev`
   - Press: `Alt+W` (return to editor tab)

**Muscle memory pattern:** `Alt+Return` → `zi` → `hx .` → `Space f` → start coding

#### Scenario 2: Web Development Workflow

**Goal:** Edit code, preview in browser, check console

1. **Open browser**
   - Press: `Alt+B`
   - Result: Chrome/Firefox opens

2. **Navigate to localhost**
   - Type: `localhost:3000`
   - Result: Dev server page loads

3. **Switch to terminal** (already open from Scenario 1)
   - Press: `Alt+J/K/I/L` (navigate Hyprland windows)
   - Or: Click terminal window (if mouse mode needed, use Caps Lock)

4. **Edit code in Helix**
   - Navigate in file: `w/b/e` for words, `j/k` for lines
   - Make changes
   - Press: `Return` to save (auto-reload in browser)

5. **Check browser**
   - Press: `Alt+J/K/I/L` to focus browser window
   - Or: `Alt+R` to next tab if browser in adjacent tab

6. **Navigate browser with Vimium**
   - Press: `f` (show link hints)
   - Type: hint letters to click link
   - Press: `j/k` to scroll page
   - Press: `/` to search on page

**Muscle memory pattern:** Edit → `Return` (save) → `Alt+L` (browser) → `f` (Vimium links) → `Alt+J` (back to editor)

#### Scenario 3: Multi-File Editing in Helix

**Goal:** Edit multiple related files efficiently

1. **Open first file**
   - In Helix: `Space f` → type `util` → select `utils.ts`

2. **Navigate to function**
   - Press: `Space s` (symbol search)
   - Type: `format` → select `formatDate` function
   - Result: Cursor jumps to function

3. **Edit function**
   - Navigate: `w` to next word, `b` to previous
   - Jump to line end: `Ctrl+E`
   - Make changes, `Return` to save

4. **Open related file (split)**
   - Press: `Ctrl+W v` (vertical split)
   - Press: `Space f` → type `comp` → select `Calendar.tsx`

5. **Navigate between splits**
   - Press: `Ctrl+W h/l` (focus left/right split)
   - Or: `Ctrl+W w` (cycle through splits)

6. **Jump to definition**
   - Cursor on `formatDate` function call
   - Press: `gd` (go to definition)
   - Result: Jumps to definition (in split or new file)

7. **Go back**
   - Press: `Ctrl+O` (jump back to previous location)

**Muscle memory pattern:** `Space f` (find) → edit → `Ctrl+W v` (split) → `gd` (definition) → `Ctrl+O` (back)

#### Scenario 4: Terminal Tab & Pane Management

**Goal:** Multiple terminal sessions for different tasks

1. **Terminal already open** with Zellij
   - Current tab: Running dev server

2. **Create new tab for git**
   - Press: `Ctrl+T` (new Zellij tab)
   - Type: `git status`

3. **Create another tab for tests**
   - Press: `Ctrl+T` (new tab)
   - Type: `npm test -- --watch`

4. **Navigate between tabs**
   - Press: `Ctrl+Shift+Tab` (previous tab)
   - Press: `Ctrl+Tab` (next tab)
   - Or: `Ctrl+PgUp` / `Ctrl+PgDn` on UHK
   - Tabs: [Dev Server] ← → [Git] ← → [Tests]

5. **Create pane in current tab** (for side-by-side view)
   - Press: `Ctrl+P` (enter pane mode)
   - Press: `n` (new pane)
   - Result: Vertical split created
   - Press: `Esc` (return to normal mode)

6. **Navigate between panes (Fastest Method)**
   - Press: `Alt+h` (focus left pane) - UHK: Fn2+h
   - Press: `Alt+l` (focus right pane) - UHK: Fn2+l
   - **No mode switching needed!**

7. **Alternative: Pane Mode Navigation**
   - Press: `Ctrl+P` (enter pane mode)
   - Press: `h/j/k/l` (focus pane in direction)
   - Or: `p` to cycle/toggle between panes
   - Press: `Esc` (return to normal mode)

8. **Quick Two-Pane Toggle Example**
   - Scenario: Code in left pane, output in right pane
   - Edit code → `Alt+l` (check output) → `Alt+h` (back to code)
   - Single keystroke switching!

9. **Close pane when done**
   - Method 1: `Ctrl+P` → `x` (close current pane)
   - Method 2: `Ctrl+D` (exit shell, closes pane)

10. **Close tab when done**
    - Press: `Ctrl+W` (close current Zellij tab)

**Muscle memory patterns:**
- **Tab navigation**: `Ctrl+T` (new) → `Ctrl+Tab` (next) → `Ctrl+W` (close)
- **Pane navigation**: `Alt+h/j/k/l` (directional, fastest)
- **Two-pane toggle**: `Alt+h` ↔ `Alt+l` (horizontal) or `Alt+j` ↔ `Alt+k` (vertical)

#### Scenario 5: Window Management Across Workspaces

**Goal:** Organize different project contexts in separate workspaces

1. **Current workspace 1:** Code editor + terminal

2. **Switch to workspace 2 for browser/docs**
   - Press: `Alt+2` (switch to workspace 2)
   - Press: `Alt+B` (open browser if not already open)

3. **Open documentation in split**
   - Press: `Alt+Return` (open terminal)
   - Type: `hx README.md`
   - Press: `Alt+I/K` (move between windows)

4. **Back to code workspace**
   - Press: `Alt+1` (switch to workspace 1)
   - Result: Return to editor + terminal

5. **Move window to different workspace**
   - Press: `Alt+Shift+3` (move current window to workspace 3)

6. **Floating window for notes**
   - Press: `Alt+V` (toggle floating)
   - Press: `Alt+mouse drag` to position (if using mouse mode)

**Muscle memory pattern:** `Alt+1-9` (workspaces) → `Alt+Shift+1-9` (move windows) → `Alt+J/K/I/L` (focus)

### Key Takeaways

**Consistent Patterns Across Tools:**
1. **Tab Navigation:** `Alt+W/E/R/C` works in Zellij and browser
2. **Window Navigation:** `Alt+J/K/I/L` works in Hyprland and as arrows everywhere
3. **Text Navigation:** `w/b/e` in Helix, `Mod+F/S` on UHK for universal use
4. **Line Navigation:** `Ctrl+A/E` works in Helix, terminal, and most text inputs

**Muscle Memory Benefits:**
- Same thumb position (Alt/Fn2) for all window/app operations
- Home row navigation (JKIL, WERC) minimizes hand movement
- Consistent patterns reduce cognitive load when switching contexts
- No mouse needed for 95% of workflows

**Workflow Efficiency:**
- Launch app: 1 keystroke (`Alt+B/Return`)
- Switch workspace: 1 keystroke (`Alt+1-9`)
- Navigate tabs: 1 keystroke (`Alt+W/R`)
- Navigate windows: 1 keystroke (`Alt+J/K/I/L`)
- Edit text: Home row only (`hjkl`, `wbe`, `Ctrl+A/E`)

---

## Nix Implementation Guide

### Module Structure

All keybindings should be managed declaratively through Nix/Home Manager. This structure works on both **NixOS** and **macOS** (via Home Manager).

```
home-manager/common/features/
├── desktop/                    # NixOS only
│   └── hyprland/
│       └── keybindings.nix     # Hyprland window manager bindings
├── cli/                        # Cross-platform (NixOS + macOS)
│   ├── ghostty/
│   │   └── keybindings.nix     # Terminal keybindings
│   ├── zellij/
│   │   └── keybindings.nix     # Multiplexer keybindings
│   └── helix/
│       └── keybindings.nix     # Editor keybindings
└── browser/                    # Cross-platform (NixOS + macOS)
    └── vimium/
        └── config.nix          # Browser extension config
```

**Cross-Platform Strategy:**
- **CLI tools** (Ghostty, Zellij, Helix): Same configuration on NixOS and macOS
- **Desktop** (Hyprland): NixOS only; macOS uses separate window manager
- **Browser** (Vimium): Identical configuration on both platforms

### Configuration Examples

#### Hyprland Keybindings Module
```nix
# home-manager/common/features/desktop/hyprland/keybindings.nix
{ config, lib, pkgs, ... }:
{
  # Example structure - to be implemented
}
```

#### Ghostty Keybindings Module
```nix
# home-manager/common/features/cli/ghostty/keybindings.nix
{ config, lib, pkgs, ... }:
{
  programs.ghostty = {
    # Example structure - to be implemented
  };
}
```

### Host-Specific Customizations
<!-- How to override defaults per-host -->

### Hardware-Specific Modules
<!-- Framework vs MacBook specific keybinding adjustments -->

---

## Migration Path

### Implementation Phases

**Phase 1: Documentation & Planning** ✅
- [x] Document current state
- [x] Research tool capabilities
- [x] Design unified keybinding scheme
- [ ] Create consistency matrix

**Phase 2: Hyprland Foundation**
- [ ] Implement complete Hyprland keybindings
- [ ] Setup window management bindings
- [ ] Configure workspace navigation
- [ ] Add app launcher bindings
- [ ] Integrate app groups from spike

**Phase 3: Terminal Stack**
- [ ] Configure Ghostty custom keybindings
- [ ] Customize Zellij for workflow
- [ ] Test Ghostty + Zellij integration

**Phase 4: Editor Enhancement**
- [ ] Enhance Helix keybindings
- [ ] Add LSP operation bindings
- [ ] Configure multi-cursor workflows

**Phase 5: Browser Integration**
- [ ] Setup Vimium configuration
- [ ] Export and version control config
- [ ] Test consistency with other tools

**Phase 6: Hardware Optimization**
- [ ] Program UHK layers
- [ ] Test on Framework laptop
- [ ] Test on MacBook (if applicable)
- [ ] Document ergonomic improvements

**Phase 7: Testing & Iteration**
- [ ] Daily usage testing (mouse-free workflows)
- [ ] Test Caps Lock mouse mode for edge cases
- [ ] Verify muscle memory portability (UHK ↔ Framework)
- [ ] Identify conflicts and issues
- [ ] Refine based on real-world usage
- [ ] Measure productivity improvements
- [ ] Document lessons learned

---

## Known Conflicts & Resolutions

This section documents keybinding conflicts discovered during implementation and their resolutions.

### Conflict 1: Ctrl+O - Zellij Session Mode vs Claude Code/Lazygit

**Issue:**
- **Zellij Default**: `Ctrl+O` enters session mode
- **Claude Code**: `Ctrl+O` = "view thinking"
- **Lazygit**: `Ctrl+O` = "copy"

**Impact**: Pressing Ctrl+O in terminal would trigger Zellij session mode instead of application-specific actions

**Resolution**: ✅ **RESOLVED**
- Unbinded Zellij's `Ctrl+O` binding
- Remapped session mode to `Ctrl+Shift+O`
- Location: `home-manager/common/features/keybindings.nix:60-65`

**Result**: Claude Code and Lazygit can now use Ctrl+O without conflict

---

### Conflict 2: Ctrl+Shift+O - Zellij Session Mode vs Ghostty Split

**Issue:**
- **Zellij Custom**: `Ctrl+Shift+O` = session mode (after moving from Ctrl+O)
- **Ghostty Default**: `Ctrl+Shift+O` = `new_split:right` (vertical split)

**Impact**: Pressing Ctrl+Shift+O could trigger both Ghostty split AND Zellij session mode

**Resolution**: ✅ **RESOLVED**
- Unbinded Ghostty's `Ctrl+Shift+O` split binding
- Strategy: Ghostty acts purely as terminal emulator, Zellij handles ALL multiplexing
- Location: `home-manager/common/features/keybindings.nix:93-95`

**Result**: Ctrl+Shift+O reliably opens Zellij session mode, no split conflicts

---

### Conflict 3: Ctrl+Shift+E - Ghostty New Tab vs Ghostty Split

**Issue:**
- **Ghostty Default**: `Ctrl+Shift+E` = `new_split:down` (horizontal split)
- **Ghostty Custom**: `Ctrl+Shift+E` = `new_tab` (our configuration)

**Impact**: Dual binding definition could cause unpredictable behavior

**Resolution**: ✅ **RESOLVED**
- Custom `new_tab` binding overrides default split binding
- Documented explicitly in configuration
- Location: `home-manager/common/features/keybindings.nix:78-80`

**Result**: Ctrl+Shift+E creates new Ghostty tab, split functionality disabled

---

### Conflict 4: Ctrl+G - Zellij Lock Mode vs Claude Code

**Issue:**
- **Zellij Default**: `Ctrl+G` enters locked mode
- **Claude Code**: `Ctrl+G` = "open prompt in editor"

**Impact**: Pressing Ctrl+G in terminal would lock Zellij instead of opening Claude Code editor

**Resolution**: ✅ **RESOLVED**
- Unbinded Zellij's `Ctrl+G` binding
- Remapped lock mode to `Ctrl+Shift+G`
- Location: `home-manager/common/features/keybindings.nix:53-58`

**Result**: Claude Code can use Ctrl+G without triggering Zellij lock mode

---

### Strategy Summary: Ghostty Splits Disabled

**Decision**: Disable ALL Ghostty split/pane management features

**Rationale**:
1. **Single Source of Multiplexing**: Zellij provides superior tab AND pane management
2. **Avoid Keybinding Conflicts**: Prevents collisions with Zellij session/mode bindings
3. **Consistent Interface**: Users learn ONE multiplexer (Zellij), not two
4. **Simplified Mental Model**: Ghostty = terminal emulator, Zellij = multiplexer

**Unbinded Ghostty Keybindings**:
- `Ctrl+Shift+O` - new_split:right
- `Ctrl+Alt+Up/Down/Left/Right` - pane navigation

**Location**: `home-manager/common/features/keybindings.nix:93-99`

---

### Prevention: How to Avoid Future Conflicts

**Before adding new keybindings:**

1. **Check tool defaults**: Run `<tool> +list-keybinds --default` (if available)
2. **Search existing config**: Check `keybindings.nix` for potential conflicts
3. **Document the binding**: Add comment explaining purpose and any overrides
4. **Test in practice**: Verify keybinding works as expected in real usage

**Conflict checklist:**
- [ ] Does this conflict with Zellij modes (Ctrl+O, Ctrl+G, Ctrl+P, etc.)?
- [ ] Does this conflict with Claude Code shortcuts?
- [ ] Does this conflict with application-specific bindings (lazygit, helix, etc.)?
- [ ] Is this tool's default behavior being overridden?
- [ ] Should we unbind the default to prevent confusion?

---

## Quick Reference Cards

### Hyprland Cheatsheet
<!-- Top 30 keybindings -->

### Terminal Stack Cheatsheet
<!-- Ghostty + Zellij common operations -->

### Helix Cheatsheet
<!-- Most-used editor commands -->

### Browser (Vimium) Cheatsheet
<!-- Essential navigation commands -->

### UHK Layer Diagram
<!-- Visual representation of layer layouts -->

---

## Additional Resources

### Documentation Links
- [Hyprland Wiki - Binds](https://wiki.hypr.land/Configuring/Binds/)
- [Ghostty Keybindings Docs](https://ghostty.org/docs/config/keybind)
- [Zellij Keybindings Guide](https://zellij.dev/documentation/keybindings.html)
- [Helix Documentation](https://docs.helix-editor.com/)
- [Vimium GitHub](https://github.com/philc/vimium)
- [UHK Agent](https://ultimatehackingkeyboard.github.io/agent/)

### Related Configuration Files
- Hyprland: `archive/home.nix:109-116`
- App Groups: `spikes/1757895719_hyprland_app_groups/`
- Helix: `home-manager/common/features/cli/helix.nix:43`
- Git: `home-manager/common/features/cli/git.nix`
- Input: `home-manager/common/features/desktop/default.nix:22-30`

---

## Contributing

This is a living document. As keybindings are implemented and tested, this documentation should be updated to reflect:
- Actual configurations that work well
- Conflicts discovered during usage
- Ergonomic improvements
- New tools added to the workflow

## Changelog

- 2026-02-19: Added move tab left/right keybindings
  - New Zellij bindings: `Ctrl+Shift+PageUp` (move left), `Ctrl+Shift+PageDown` (move right)
  - UHK: `Mod+Shift+W` (left), `Mod+Shift+R` (right)
  - Framework: `Fn+Ctrl+Shift+Arrow Up/Down`
  - Updated Hardware Translation Table with new bindings
  - Added documentation sync reminder comment to keybindings.nix

- 2025-12-28: Clarified altwin:swap_alt_win ergonomics and browser navigation
  - Updated "Why the swap?" section to emphasize ergonomic benefits:
    - Physical Alt in thumb position for frequent Hyprland window management
    - Physical Super for browser back/forward (Alt+Left/Right after swap)
  - Added "Browser Back/Forward (Standard Shortcuts)" section explaining native navigation
  - No UHK macros needed for browser back/forward - just physical Super + arrow keys

- 2025-12-21: Added UHK browser navigation
  - Documented `Mod + Super + J/L` for browser back/forward (Alt+Left/Right Arrow)
  - Added to UHK Mod Layer section and Hardware Translation Table

- 2025-10-25: Initial outline created
  - Added comprehensive structure for all tools (Hyprland, Ghostty, Zellij, Helix, Browser/Vimium)
  - Documented mouse-free workflow philosophy
  - Clarified modifier key strategy: Hyprland uses Super, accessed via Alt (swapped via `altwin:swap_alt_win`)
  - Documented current UHK Fn2 layer configuration (manually configured Alt+JKIL mappings)
  - Added Framework laptop portability strategy (direct Alt+JKIL usage)
  - **Added portable programmable keyboard section (QMK/ZMK)**
    - OS-level configuration strategy for maximum portability
    - Hardware-independent approach (any programmable keyboard sends Alt codes)
    - Recommended keyboards: Corne, Planck, Preonic, Lily58, Kyria
    - Migration checklist for new keyboards
  - **Documented tab navigation pattern (W/E/R/C)**
    - UHK Mod layer: Current sends Ctrl+PgUp/PgDn/T/W, recommended Alt+W/E/R/C
    - Works in: Browser (current), Ghostty (current), needs Zellij configuration
    - Added Zellij keybinding configuration examples (both options)
    - Browser/Vimium configuration for Alt+W/E/R/C
    - Updated consistency matrix with tab navigation operations
    - Updated hardware translation table with tab navigation for all keyboards
    - Framework strategy: Use Alt+W/E/R/C directly (matches UHK recommended config)
  - Created hardware translation table for UHK ↔ Framework ↔ Portable Keyboard ↔ MacBook
  - Documented ergonomic principles and Caps Lock mouse mode
  - Added keybinding consistency matrix across all tools (spatial nav + tab nav)
  - Outlined 7-phase migration path
  - **Emphasized portability-first strategy**: Single OS configuration works with any programmable keyboard
  - **macOS clarifications**:
    - MacBook runs macOS (not Hyprland)
    - Home Manager manages cross-platform tool configs (Ghostty, Zellij, Helix)
    - Window management requires macOS-specific tools (Aerospace, yabai)
  - **Added Common Workflows & Use Cases section**:
    - Application launching: Alt+B (browser), Alt+Return (terminal)
    - Terminal workflow with zoxide (z/zi for directory navigation)
    - Text navigation patterns: UHK Mod+F/S, Helix w/b/e, Ctrl+A/E
    - Five detailed workflow scenarios:
      1. Starting a coding session (terminal → editor → dev server)
      2. Web development (edit → browser → Vimium)
      3. Multi-file editing in Helix (splits, go-to-definition)
      4. Terminal tab/pane management with Zellij
      5. Window management across Hyprland workspaces
    - Key takeaways: consistency, muscle memory, efficiency metrics
  - **Added documentation references**:
    - Helix: Official keymap docs and `:help keymap` command
    - Hyprland: `~/.config/hypr/hyprland.conf` location
    - Ghostty: `ghostty +list-keybinds --default` command
    - Zellij: Default keybindings KDL file on GitHub
  - **Implemented unified tab navigation**:
    - Created `home-manager/common/features/keybindings.nix` module
    - Configured Zellij for Ctrl+PgUp/PgDn (UHK/portable) and Ctrl+Tab (Framework/all)
    - Disabled Ghostty native tabs (Zellij handles all multiplexing)
    - Updated cli/default.nix to import keybindings module
    - Documented Framework PgUp/PgDn access: Fn+Arrow Up/Down
    - Added complete "Tab Navigation Across Tools" section
    - Included workflow examples for UHK and Framework
    - Module structure: Single keybindings.nix for all tools, keeps enable settings in original locations
