-- WezTerm configuration.
--
-- This file is a symlink target: ~/.config/wezterm points into the repository, so
-- edits here take effect in the running terminal immediately and land in git
-- without a `chezmoi apply` round trip.
--
-- Font comes from the font-jetbrains-mono-nerd-font cask declared in
-- packages.yaml. Nerd Font glyphs are what the snacks picker and gitsigns draw
-- their icons with; without it the editor renders boxes.

local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback({
  'JetBrainsMono Nerd Font',
  'Menlo',
})
config.font_size = 14.0
config.line_height = 1.1

-- Dracula matches the herdr theme in live/herdr/config.toml. One palette across
-- the tools that sit in the same window is worth more than a per-tool optimum.
config.color_scheme = 'Dracula (Official)'

config.window_decorations = 'RESIZE'
config.window_padding = { left = 8, right = 8, top = 8, bottom = 4 }
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.scrollback_lines = 10000

-- Neovim and herdr both read the terminal's own key handling, so keep the
-- bindings minimal and leave the rest of the keyboard to whatever is running.
config.keys = {
  { key = 'd', mods = 'CMD',       action = wezterm.action.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
  { key = 'd', mods = 'CMD|SHIFT', action = wezterm.action.SplitVertical({ domain = 'CurrentPaneDomain' }) },
  { key = 'w', mods = 'CMD',       action = wezterm.action.CloseCurrentPane({ confirm = true }) },
  { key = '[', mods = 'CMD',       action = wezterm.action.ActivatePaneDirection('Prev') },
  { key = ']', mods = 'CMD',       action = wezterm.action.ActivatePaneDirection('Next') },
}

return config
