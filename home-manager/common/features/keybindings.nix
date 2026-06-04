{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Centralized Keybinding Configuration
  # ONLY keybinding settings - enable/theme/other configs stay in respective modules
  #
  # IMPORTANT: Any changes to this file MUST be documented in docs/KEYBINDINGS.md
  # Keep the documentation in sync with the actual configuration.
  #
  # Tab Navigation Strategy:
  # - Browser-standard shortcuts (Ctrl+PgUp/PgDn, Ctrl+Tab) work in Chrome, Firefox, Zellij, most apps
  # - UHK Mod layer: W/E/R/C → Ctrl+PgUp/T/PgDn/W for ergonomic home row access
  # - Framework laptop: Fn+Ctrl+Arrow (PgUp/PgDn) or Ctrl+Tab (no Fn needed)
  # - Both methods supported for flexibility across hardware

  # Zellij - Terminal Multiplexer Tab Navigation
  programs.zellij.settings.keybinds = {
    normal = {
      # Previous tab: Ctrl+PgUp
      # - UHK: Mod+W → Ctrl+PgUp
      # - Framework: Fn+Ctrl+Arrow Up → Ctrl+PgUp
      # - Works in: Zellij, Chrome, Firefox, many apps
      "bind \"Ctrl PageUp\"" = {
        GoToPreviousTab = { };
      };

      # Next tab: Ctrl+PgDn
      # - UHK: Mod+R → Ctrl+PgDn
      # - Framework: Fn+Ctrl+Arrow Down → Ctrl+PgDn
      # - Works in: Zellij, Chrome, Firefox, many apps
      "bind \"Ctrl PageDown\"" = {
        GoToNextTab = { };
      };

      # Previous tab (alternative): Ctrl+Shift+Tab
      # - All keyboards: Ctrl+Shift+Tab (no Fn needed)
      # - Browser-standard, works everywhere
      "bind \"Ctrl Shift Tab\"" = {
        GoToPreviousTab = { };
      };

      # Next tab (alternative): Ctrl+Tab
      # - All keyboards: Ctrl+Tab (no Fn needed)
      # - Browser-standard, works everywhere
      "bind \"Ctrl Tab\"" = {
        GoToNextTab = { };
      };

      # Previous tab (home-row alt): Alt+[
      # - Framework: single-hand, no Fn juggling vs Fn+Ctrl+Arrow
      "bind \"Alt [\"" = {
        GoToPreviousTab = { };
      };

      # Next tab (home-row alt): Alt+]
      # - Framework: single-hand, no Fn juggling vs Fn+Ctrl+Arrow
      "bind \"Alt ]\"" = {
        GoToNextTab = { };
      };

      # New tab: Ctrl+T
      # - UHK: Mod+E → Ctrl+T
      # - Framework: Ctrl+T
      # - Universal browser/app standard
      "bind \"Ctrl t\"" = {
        NewTab = { };
      };

      # Close tab: Ctrl+W
      # - UHK: Mod+C → Ctrl+W
      # - Framework: Ctrl+W
      # - Universal browser/app standard
      "bind \"Ctrl w\"" = {
        CloseTab = { };
      };

      # Unbind default Ctrl+G (which normally enters locked mode)
      # Conflict avoided: Ctrl+G is used by Claude Code for "open prompt in editor"
      "unbind \"Ctrl g\"" = [ ];

      # Lock mode: Ctrl+Shift+G (custom binding, replaces default Ctrl+G)
      "bind \"Ctrl Shift g\"" = {
        SwitchToMode = "locked";
      };

      # Unbind default Ctrl+O (which normally enters session mode)
      # Conflicts avoided: Ctrl+O is used by Claude Code for "view thinking" and lazygit for "copy"
      "unbind \"Ctrl o\"" = [ ];

      # Session mode: Ctrl+Shift+O (custom binding, replaces default Ctrl+O)
      "bind \"Ctrl Shift o\"" = {
        SwitchToMode = "session";
      };
    };
  };

  # Ghostty - Tab Navigation with Shift Modifier
  # Strategy: Ghostty acts as simple terminal emulator, Zellij handles all multiplexing
  # - Ghostty tabs use Ctrl+Shift+W/E/R/C to avoid conflict with Zellij
  # - Ghostty splits are DISABLED (Zellij handles all panes)
  # - Zellij uses Ctrl+PgUp/PgDn/Tab/T/W (no shift)
  programs.ghostty.settings.keybind = [
    # Previous tab: Ctrl+Shift+W (original W + shift)
    "ctrl+shift+w=previous_tab"

    # New tab: Ctrl+Shift+E (original E + shift)
    # Note: Overrides Ghostty's default Ctrl+Shift+E (new_split:down)
    "ctrl+shift+e=new_tab"

    # Next tab: Ctrl+Shift+R (original R + shift)
    "ctrl+shift+r=next_tab"

    # Close tab: Ctrl+Shift+C (original C + shift)
    "ctrl+shift+c=close_surface"

    # Unbind Zellij tab shortcuts to ensure Zellij receives them
    "ctrl+page_up=unbind"
    "ctrl+page_down=unbind"
    "ctrl+tab=unbind"

    # Unbind Ghostty splits - Zellij handles all pane management
    # Conflict resolution: Ctrl+Shift+O would conflict with Zellij session mode
    "ctrl+shift+o=unbind" # Default: new_split:right
    "ctrl+alt+up=unbind" # Default: navigate to pane above
    "ctrl+alt+down=unbind" # Default: navigate to pane below
    "ctrl+alt+left=unbind" # Default: navigate to pane left
    "ctrl+alt+right=unbind" # Default: navigate to pane right
  ];

  # Future keybinding configurations:
  # - Helix: programs.helix.settings.keys = { ... };
  # - Browser/Vimium: Export and track configuration
}
