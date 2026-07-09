# GNOME dotfiles

GNOME stores settings in the dconf database, not files. `keystone.dconf` is
the editable source of truth; Home Manager links this directory to
`~/.config/gnome-keystone/`.

The iteration loop:

1. Edit `keystone.dconf` in your ks-config repo.
2. Run `keystone-gnome-apply` (wraps `dconf load -f / < keystone.dconf`).
3. Keybindings are live immediately — no rebuild, no logout.

To capture a change you made through GNOME Settings back into source, diff
`dconf dump /` against this file and fold the relevant lines in.

See `docs/documentation/gnome.md` in keystone-desktop for keyboard usage.
