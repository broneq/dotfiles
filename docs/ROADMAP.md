# Roadmap

Execution plan for this dotfiles repository. Phases are ordered so that every one
of them leaves the machine in a working state. You can stop after any phase.

Phases 0 through 6 are **additive**: they record existing state and bind it to git.
Nothing is uninstalled. Phase 7 is the only destructive one and is deliberately
last.

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done.

---

## Current state

Surveyed on the `managed` machine, 2026-09-17. This is the baseline every phase
works against.

### Machine

| Property | Value |
|---|---|
| Profile | `managed` |
| MDM | Mosyle, DEP-enrolled, user-approved |
| Admin rights | none (groups: `staff`, `everyone`, `localaccounts`, ...) |
| Homebrew prefix | `/opt/homebrew`, owned by the login user |
| Shell | zsh |

Consequence: Homebrew formulae install fine without `sudo` because the user owns
the prefix. GUI casks must target `$HOME/Applications`.

### Packages in use

**Homebrew formulae (24):** `actionlint`, `beads`, `colima`, `docker`,
`docker-buildx`, `docker-compose`, `fd`, `gh`, `git-filter-repo`, `go`,
`graphviz`, `hey`, `htop`, `midnight-commander`, `mkcert`, `neovim`, `nvm`,
`pandoc`, `poppler`, `python@3.14`, `ripgrep`, `rtk`, `tree`, `watch`, `whistle`

`ripgrep` and `fd` were added on 2026-09-17 as hard dependencies of the Neovim
picker. Snacks `grep` has no search backend without `ripgrep`.

**Homebrew casks (2):** `font-jetbrains-mono-nerd-font`, `opensuperwhisper`

**npm global, pinned under nvm node v24.21.0 (5):** `chrome-devtools-axi`,
`gh-axi`, `lavish-axi`, `quota-axi`, `tasks-axi`

**uv tools (1):** `code-review-graph`

**Standalone binaries in `~/.local/bin`:** `claude`, `herdr` (20 MB),
`treehouse` (12 MB), `uv` (41 MB), `no-mistakes`

**Installed outside any package manager:** WezTerm, at
`~/Applications/WezTerm.app`. No cask registered, no config yet.

### Authored configuration

| Path | Size | Handling |
|---|---|---|
| `~/.zshrc` | 827 B | template |
| `~/.zprofile` | 173 B | managed file |
| `~/.config/nvim/` | ~4 KB, 7 files | symlink directory |
| `~/.config/wezterm/` | does not exist yet | symlink directory |
| `~/.config/herdr/config.toml` | 132 B | symlink file |
| `~/.claude/CLAUDE.md` | 1.5 KB | managed file |
| `~/.claude/RTK.md` | 964 B | managed file |
| `~/.claude/settings.json` | 6.2 KB | **template** |
| `~/.claude/hooks/herdr-agent-state.sh` | 3.0 KB | managed file, executable |
| `~/.agents/.skill-lock.json` | 5.2 KB | managed file, drives skill restore |

Total authored surface: about 20 files, under 60 KB.

### Neovim

Restructured on 2026-09-17 from a single `init.lua` into a modular layout.
Neovim 0.12.4. Plugin manager: `lazy.nvim`, pinned by `lazy-lock.json`.

```
~/.config/nvim/
  init.lua                  # two requires, nothing else
  lua/vim_config.lua        # mapleader = space, set before any plugin loads
  lua/plugin.lua            # lazy bootstrap + require('lazy').setup('plugins')
  lua/plugins/
    codediff.lua
    git.lua
    markdown.lua
    navigation.lua
    ui.lua
```

`setup('plugins')` loads every file in `lua/plugins/`. Adding a plugin is a new
file; removing one is deleting that file. Nothing else needs to change.

| Plugin | Role | Keys |
|---|---|---|
| `folke/snacks.nvim` | picker, notifier, input | `<leader>f` files, `<leader>s` grep, `<leader>b` buffers |
| `NeogitOrg/neogit` | git UI (pulls `plenary`, `diffview`) | `<leader>g` |
| `lewis6991/gitsigns.nvim` | gutter signs, inline blame | automatic |
| `folke/which-key.nvim` | leader key discovery popup | automatic |
| `MeanderingProgrammer/render-markdown.nvim` | in-buffer markdown formatting | automatic on `.md` |
| `selimacerbas/markdown-preview.nvim` | browser preview with mermaid and KaTeX (pulls `live-server.nvim`) | `<leader>mp` start, `<leader>mP` stop, `<leader>mr` refresh |
| `esmuellert/codediff.nvim` | diff viewer, pre-existing | `:CodeDiff` |

Deliberately **not** included, to be revisited:

- No LSP, no completion, no `nvim-treesitter`. Neovim 0.12 already ships the
  `markdown`, `markdown_inline`, `html` and `yaml` parsers, which is all
  `render-markdown` needs.
- No `gd` mapped to `Snacks.picker.lsp_definitions()`. Without a configured LSP
  server that mapping does nothing. Add it together with `nvim-lspconfig`, never
  before.
- No `oil.nvim`. Directory navigation is currently `mc` outside the editor.
  Re-evaluate after using the snacks picker for a while.

Mermaid renders in the browser preview, not in the buffer. Inline diagram
rendering needs the Kitty graphics protocol, which the current terminal (iTerm2)
does not support and which WezTerm supports only partially. See "Open questions".

### Runtime state, never versioned

`~/.claude/projects` (1.5 GB), `~/.claude/plugins` (53 MB), `~/.claude/jobs`
(33 MB), `~/.claude/file-history` (15 MB), `~/.claude/history.jsonl` (7.3 MB),
`~/.config/herdr/herdr-server.log` (4.9 MB), `~/.config/herdr/*.sock`,
`~/.config/herdr/session.json`.

Neovim plugin payloads live in `~/.local/share/nvim/lazy/`, outside the config
directory, which is why `~/.config/nvim` can be symlinked wholesale.

### Known defects to fix during migration

1. **Dead alias.** `~/.zshrc` defines `claude-mem` pointing at
   `~/.claude/plugins/cache/thedotmack/claude-mem/10.5.5/...`. The version is
   hardcoded into a cache path and `claude-mem` is no longer in the installed
   plugin set. The alias is already broken. Remove it.
2. **`~/.zshrc` will not survive a fresh machine.** `. "$HOME/.local/bin/env"` is
   unguarded and aborts the shell if `uv` is not yet installed. Guard it.
3. **Hardcoded home path** appears three times in `~/.zshrc`. Replace with `$HOME`.
4. **Homebrew PATH set twice**, manually in `.zshrc` and via `brew shellenv` in
   `.zprofile`. Keep `brew shellenv` only.
5. **Dead file.** `~/.claude/statusline-command.sh` is unreferenced;
   `settings.json` uses `statusLine.command = "bunx -y ccstatusline@latest"`.
   Do not version it. Delete it.
6. **Hidden cross-repo dependency.** `settings.json` registers a plugin
   marketplace at `<home>/projects/bdk`, a local directory. The `bdk` repo must be
   cloned there or the plugin fails to load. Phase 5 makes this explicit.

---

## Phase 0: Repository skeleton

**Goal:** an empty but valid chezmoi source tree, with the profile prompt working.

- [ ] `git init`, add `.gitignore` covering `live/**/*.log`, `live/**/*.sock`, `.DS_Store`
- [ ] Create `.chezmoiroot` containing `home`
- [ ] Create `home/.chezmoi.toml.tmpl` with `promptChoiceOnce` over
      `managed` / `owned`, stored as `.profile`
- [ ] Add a profile-vs-reality assertion: if `.profile` is `owned`, require admin
      group membership; abort otherwise
- [ ] Run `chezmoi init --source ~/projects/dotfiles` and confirm the prompt fires
      exactly once

**Done when:** `chezmoi data` prints the chosen profile and `chezmoi apply` is a
no-op.

---

## Phase 1: Package inventory

**Goal:** every installed tool is declared in one file, and re-installable.

- [ ] Create `home/.chezmoidata/packages.yaml` with the four channels and the
      profile split from "Current state" above
- [ ] Split casks into `user_level` (fonts, installs to `~/Library`) and
      `app_bundle` (needs an `--appdir` override on `managed`)
- [ ] `run_onchange_10-brew.sh.tmpl`: render a Brewfile from YAML, run
      `brew bundle`. **No `--cleanup`, no `--force`.** Pass
      `--appdir="$HOME/Applications"` when profile is `managed`
- [ ] `run_onchange_30-npm-global.sh.tmpl`: install the five `*-axi` packages
- [ ] `run_onchange_40-uv-tools.sh.tmpl`: bootstrap `uv` if absent, then
      `uv tool install` each entry
- [ ] Add WezTerm as a cask and drop the manual `~/Applications/WezTerm.app`
      install, so it becomes managed like everything else

**Done when:** a second `chezmoi apply` produces no changes and installs nothing.

**Risk:** low. Nothing is removed. Worst case a package is already present and
`brew bundle` reports it as satisfied.

---

## Phase 2: Configuration files

**Goal:** all authored config lives in the repo, and application-written files
stay editable in place.

- [ ] Create `live/` and move the real files there: `nvim/`, `wezterm/`,
      `herdr/config.toml`
- [ ] Add `symlink_*.tmpl` entries pointing at `{{ .chezmoi.sourceDir }}/../live/...`
- [ ] Add managed files: `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`,
      `~/.claude/hooks/herdr-agent-state.sh` (mode 0755)
- [ ] Add `~/.claude/settings.json` as a template with exactly two substitutions:
      the `bdk` marketplace path and the hook path, both via `{{ .chezmoi.homeDir }}`
- [ ] Write the first WezTerm config in `live/wezterm/wezterm.lua`: JetBrains Mono
      Nerd Font, theme, sensible keybindings
- [ ] Delete `~/.claude/statusline-command.sh`
- [ ] Delete `~/.config/nvim/init.lua.bak` once the new layout has been used for a
      few days and the old single-file config is no longer wanted

### Neovim specifics

Move the whole of `~/.config/nvim` (7 files) into `live/nvim/` and symlink it.
Plugin payloads live in `~/.local/share/nvim/lazy/`, so nothing large follows.

- [ ] Commit `lazy-lock.json` together with the config. It pins every plugin to a
      commit and is what makes a fresh machine reproduce this exact setup
- [ ] Confirm `ripgrep` and `fd` are in `packages.yaml` before this phase lands.
      Without them the snacks picker is installed but non-functional, which is a
      worse state than not having it
- [ ] Verify headlessly after apply, not by opening the editor and looking:

```sh
nvim --headless -c 'lua
  assert(vim.g.mapleader == " ")
  assert(_G.Snacks)
  assert(vim.fn.executable("rg") == 1 and vim.fn.executable("fd") == 1)
  print("nvim OK")' +qa
```

**Done when:** `chezmoi diff` is empty, `~/.config/nvim` is a symlink into the
repo, the headless assertion above passes, and editing `live/wezterm/wezterm.lua`
changes the running terminal without running `chezmoi apply`.

**Risk:** low, but verify the `~/.claude` whitelist by hand. Accidentally adding
the directory instead of its files would pull in 1.5 GB.

---

## Phase 3: Shell cleanup

**Goal:** `~/.zshrc` that works on a machine where nothing is installed yet.

- [ ] Port `.zshrc` to a template, fixing defects 1 through 4 from "Current state"
- [ ] Guard every `source` with an existence test
- [ ] Keep `brew shellenv` in `.zprofile` as the only PATH entry point for Homebrew
- [ ] Verify with `zsh -l -c 'exit'` under a temporary `HOME` where no tools exist

**Done when:** a login shell in an empty `HOME` starts with no errors.

---

## Phase 4: Profiles and git identity

**Goal:** one repo, correct identity and package set on both machines.

- [ ] Add `~/.gitconfig` as a template; email switches on `.profile`
- [ ] Confirm the profile-driven package split renders correctly for both values
      (`chezmoi execute-template` against each)
- [ ] Document in `README.md` how to bootstrap the second machine

**Done when:** `chezmoi execute-template` with `profile=owned` produces a Brewfile
containing the admin-only casks, and with `profile=managed` does not.

---

## Phase 5: Claude agent layer

**Goal:** plugins and skills reproducible on a fresh machine.

- [ ] Version `~/.agents/.skill-lock.json`
- [ ] Write `run_onchange_50-claude-skills.sh.tmpl`: for each entry in the lock
      file, clone `sourceUrl` into a temp dir and copy `skillPath`'s folder into
      `~/.agents/skills/<name>`, then symlink into `~/.claude/skills`
- [ ] Make the `bdk` cross-repo dependency explicit: clone
      `<home>/projects/bdk` if missing, or fail with a clear message
- [ ] Confirm plugins restore from `settings.json` alone
      (`enabledPlugins` + `extraKnownMarketplaces`), with no need to reproduce
      `installed_plugins.json` or the plugin cache

**Done when:** deleting `~/.agents/skills` and running `chezmoi apply` restores
all 15 skills.

**Note:** there is no `skills` CLI on this machine. The lock file is written by an
agent-side skill, not a package manager, so restore must be our own script. This
is the phase most likely to need iteration.

---

## Phase 6: CI

**Goal:** prove a fresh machine works, without owning a fresh machine.

- [ ] `.github/workflows/test.yml` on `macos-latest`
- [ ] Job 1: `shellcheck` over every script
- [ ] Job 2: `chezmoi apply` into a throwaway `HOME` with `profile=managed`, then
      assert the expected symlinks and files exist
- [ ] Job 3: same with `profile=owned`, asserting the profile split diverges
- [ ] Do not install the full package set in CI; assert the rendered Brewfile
      instead. Installing 22 formulae per run buys little and costs minutes

**Done when:** CI is green and a deliberately broken template turns it red.

---

## Phase 7: nvm to mise migration

**Goal:** one version manager for node, python, go and bun.

**This is the only destructive phase. Do it alone, after everything else is
committed and CI is green.**

- [ ] Record the exact current global npm package list and node version
      (v24.21.0) in the plan before touching anything
- [ ] Add `mise` to `packages.yaml` and install it
- [ ] Declare runtimes in `home/dot_config/mise/config.toml.tmpl`
- [ ] Resolve the node situation: `whistle` pulls in a Homebrew `node` that is
      independent of nvm's v24.21.0. Decide its fate before adding a third node
- [ ] Reinstall the five `*-axi` packages under the mise-managed node
- [ ] Verify each of the five resolves and runs
- [ ] Only then: remove `nvm` from the Brewfile, remove the nvm block from `.zshrc`
- [ ] Leave `~/.nvm` on disk for one week as a rollback path, then delete manually

**Risk: high.** The five `*-axi` tools live under
`~/.nvm/versions/node/v24.21.0/lib`. Removing nvm before reinstalling them removes
half the toolbox. The ordering above exists precisely to prevent that.

**Rollback:** reinstall `nvm` via Homebrew and restore the `.zshrc` block from git.

---

## Open questions

- [x] **Resolved.** `brew uses --installed` reports no dependents for either
      `python@3.14` or `go`. Both are free to move to mise in phase 7.
- [ ] **Three node installations will exist unless phase 7 handles it.** `whistle`
      depends on the Homebrew `node` formula, which is installed as a transitive
      dependency and is separate from nvm's v24.21.0. Adding mise makes a third.
      Decide in phase 7 whether `whistle` moves to an npm global under mise, or
      whether the Homebrew `node` stays as an accepted private dependency of one
      formula. Do not try to make Homebrew's `node` the mise-managed one.
- [ ] `treehouse`, `no-mistakes` and `herdr` are standalone binaries in
      `~/.local/bin` with no declared installer. Find their upstream install
      method, or accept them as a documented manual step.
- [ ] Does the `owned` machine need the full container stack (colima, docker), or
      is that work-only tooling?
- [ ] **Terminal choice affects what Neovim can display.** Inline images and
      inline mermaid rendering in the buffer require the Kitty graphics protocol.
      `snacks.image` supports Kitty, Ghostty and tmux fully; WezTerm only
      partially, with inline rendering unsupported; iTerm2, the current terminal,
      not at all. WezTerm is already installed and slated for phase 1. Decide
      whether inline rendering matters enough to prefer Ghostty instead, before
      writing a WezTerm config worth keeping.
- [ ] Revisit the Neovim editing layer once the current set has been used in
      anger: LSP (`nvim-lspconfig`), completion (`blink.cmp`), and directory
      navigation (`oil.nvim`). All three are deliberately absent today.

## Decisions log

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-17 | chezmoi over nix-darwin and over a plain bash script | Whitelisting individual files fits the 1.5 GB `~/.claude` problem; templating is needed for two profiles; Nix loses most of its value once system defaults are out of scope |
| 2026-09-17 | Profiles named `managed` / `owned`, not `work` / `personal` | The axis that drives every branch in the config is privilege level, not employer |
| 2026-09-17 | No secrets in the repository | Nothing in scope needs them; keeps the whole encryption layer out of the design |
| 2026-09-17 | No `brew bundle --cleanup` on `managed` | MDM pushes software the script cannot distinguish from user-installed leftovers |
| 2026-09-17 | `settings.json` as a template, synced back with `chezmoi re-add` | Only two substitutions are needed; a sync layer would cost more than the two commands it saves |
| 2026-09-17 | Repository stays private | It enumerates the tooling of an MDM-managed machine |
| 2026-09-17 | Neovim config split into `lua/plugins/*.lua`, one file per area | Removing a plugin becomes deleting a file, which is what a testing phase needs |
| 2026-09-17 | Leader key is space | It was unset, so it silently sat on the default `\`; space is the de facto standard and does nothing useful in normal mode |
| 2026-09-17 | `gd` to `lsp_definitions` deliberately omitted | No LSP server is configured, so the mapping would be dead on arrival. Copying another config's defect is still a defect |
| 2026-09-17 | Markdown split across two plugins | Formatting and diagram rendering are different problems: `render-markdown` is virtual text and works in any terminal, mermaid must become a picture and needs either a browser or a graphics-capable terminal |
| 2026-09-17 | `selimacerbas/markdown-preview.nvim` over `iamcco/markdown-preview.nvim` | The iamcco plugin needs a node and yarn build step, exactly the class of thing that breaks fresh-machine bootstrap and the phase 6 CI. Accepted risk: the chosen plugin is young (199 stars) |
| 2026-09-17 | `nvim-treesitter` not installed | Neovim 0.12 already ships every parser `render-markdown` needs. Adding it would be a dependency with no current purpose |
