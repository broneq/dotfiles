-- WezTerm configuration.
--
-- This file is a symlink target: ~/.config/wezterm points into the repository, so
-- edits here take effect in the running terminal immediately and land in git
-- without a `chezmoi apply` round trip.
--
-- Nothing may live at ~/.wezterm.lua. WezTerm reads that path first and stops
-- there, so a file left behind silently shadows this one: the symlink appears,
-- `chezmoi diff` is empty, and the terminal keeps its old configuration.
-- `home/.chezmoiremove` deletes it on every apply for that reason.
--
-- Font comes from the font-jetbrains-mono-nerd-font cask declared in
-- packages.yaml. Nerd Font glyphs are what the snacks picker and gitsigns draw
-- their icons with; without it the editor renders boxes.

local wezterm = require('wezterm')
local config = wezterm.config_builder()
local act = wezterm.action

local font_stack = {
  'JetBrainsMono Nerd Font Mono',
  'Monaco',
}

config.font = wezterm.font_with_fallback(font_stack)
config.font_size = 12.0

-- Colours, font and the key and mouse bindings below reproduce the iTerm2
-- "Default" profile this setup came from, down to "Use Bright Bold". The palette
-- is deliberately not the Dracula scheme: herdr paints its own Dracula in
-- truecolor and never touches the terminal's ANSI palette, so a scheme here
-- would only recolour the shell, ls, git and Neovim, at the cost of a background
-- that was chosen on purpose.
config.bold_brightens_ansi_colors = 'BrightAndBold'

config.colors = {
  foreground = '#dcdcdc',
  background = '#15191f',
  cursor_bg = '#ffffff',
  cursor_fg = '#000000',
  cursor_border = '#ffffff',
  selection_bg = '#b3d7ff',
  selection_fg = '#000000',
  ansi = {
    '#14191e', '#b43c2a', '#00c200', '#c7c400',
    '#2744c7', '#c040be', '#00c5c7', '#c7c7c7',
  },
  brights = {
    '#686868', '#dd7975', '#58e790', '#ece100',
    '#a7abf2', '#e17ee1', '#60fdff', '#ffffff',
  },
}

-- Dim text (SGR 2) is what Claude Code draws its input suggestion with, and what
-- most TUIs use for secondary labels. WezTerm implements Intensity=Half by
-- swapping in a lighter face - JetBrains Mono ships ExtraLight, so it gets
-- picked - and leaves the colour at full foreground. The suggestion then reads
-- as text you already typed. These rules pin the regular weight and set the
-- colour explicitly: foreground blended halfway into the background, which is
-- what a terminal that dims by colour (iTerm2, Ghostty) produces.
--
-- `foreground` is a field of the TextStyle returned by wezterm.font*, not of the
-- attributes table passed into it. Attributes silently drop unknown keys, so a
-- colour written there is lost without any error.
local dim_fg = (function()
  local fr, fg, fb = wezterm.color.parse(config.colors.foreground):srgba_u8()
  local br, bg, bb = wezterm.color.parse(config.colors.background):srgba_u8()
  return string.format('#%02x%02x%02x', (fr + br) // 2, (fg + bg) // 2, (fb + bb) // 2)
end)()

local function dim_style(attrs)
  local style = wezterm.font_with_fallback(font_stack, attrs)
  style.foreground = dim_fg
  return style
end

config.font_rules = {
  { intensity = 'Half', italic = false, font = dim_style({ weight = 'Regular' }) },
  { intensity = 'Half', italic = true, font = dim_style({ weight = 'Regular', style = 'Italic' }) },
}

config.window_padding = { left = 4, right = 4, top = 4, bottom = 0 }
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

-- Neovim and herdr both read the terminal's own key handling, so keep the
-- bindings minimal and leave the rest of the keyboard to whatever is running.
--
-- The arrow, backspace and delete rows are iTerm2's "Natural Text Editing"
-- preset: they send the readline control codes the shell and every TUI already
-- understand. Without them CMD+Left does nothing and OPT+Left emits a raw escape.
config.keys = {
  { key = 'd', mods = 'CMD', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
  { key = 'd', mods = 'CMD|SHIFT', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
  { key = 'w', mods = 'CMD', action = act.CloseCurrentPane({ confirm = true }) },
  { key = '[', mods = 'CMD', action = act.ActivatePaneDirection('Prev') },
  { key = ']', mods = 'CMD', action = act.ActivatePaneDirection('Next') },

  { key = 'LeftArrow', mods = 'CMD', action = act.SendString('\x01') }, -- start of line (ctrl+a)
  { key = 'RightArrow', mods = 'CMD', action = act.SendString('\x05') }, -- end of line (ctrl+e)
  { key = 'LeftArrow', mods = 'OPT', action = act.SendString('\x1bb') }, -- word left
  { key = 'RightArrow', mods = 'OPT', action = act.SendString('\x1bf') }, -- word right
  { key = 'Backspace', mods = 'CMD', action = act.SendString('\x15') }, -- kill to start of line (ctrl+u)
  { key = 'Backspace', mods = 'OPT', action = act.SendString('\x1b\x7f') }, -- kill word backwards
  { key = 'phys:Delete', mods = 'NONE', action = act.SendString('\x04') }, -- delete forward (ctrl+d)
  { key = 'phys:Delete', mods = 'OPT', action = act.SendString('\x1bd') }, -- delete word forward
}

-- CMD+click opens the link under the cursor. `mouse_reporting` and `alt_screen`
-- are what make it work inside nvim, herdr and Claude Code, which all grab the
-- mouse themselves. The Nop on the Down event is load-bearing: without it WezTerm
-- starts a text selection before the Up event ever fires.
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = act.OpenLinkAtMouseCursor,
    mouse_reporting = true,
    alt_screen = 'Any',
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = act.Nop,
    mouse_reporting = true,
    alt_screen = 'Any',
  },
}

return config
