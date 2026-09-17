# Roadmap

Execution plan for this dotfiles repository. Phases are ordered so that every one
of them leaves the machine in a working state. You can stop after any phase.

Phases 0 through 6 are **additive**: they record existing state and bind it to git.
Nothing is uninstalled. Phase 7 is the only destructive one and is deliberately
last.

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done.

`[~]` is the honest state for most of what was written on 2026-09-17. Corrected
twice the same day: the tree has now been executed, but only its file layer, and
only against throwaway destinations. CI has run on `macos-latest` and is green,
which makes the file layer genuinely fresh-machine tested. `chezmoi` was installed on the `managed` machine and `chezmoi init`
plus `chezmoi apply --exclude=scripts` were run into temporary directories under
both profiles, which is what found the defects listed under "Defects found by the
first execution". **No install script has ever run**: no `brew bundle`, no npm
globals, no uv tools, no skill clone, no hook installer. The real machine has had
nothing applied to it. Verification still happens on a dedicated test account, and
the boxes stay `[~]` until each "Done when" has actually been observed there.

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

**Homebrew formulae (25):** `actionlint`, `beads`, `colima`, `docker`,
`docker-buildx`, `docker-compose`, `fd`, `gh`, `git-filter-repo`, `go`,
`graphviz`, `hey`, `htop`, `midnight-commander`, `mkcert`, `neovim`, `nvm`,
`pandoc`, `poppler`, `python@3.14`, `ripgrep`, `rtk`, `tree`, `watch`, `whistle`

`ripgrep` and `fd` were added on 2026-09-17 as hard dependencies of the Neovim
picker. Snacks `grep` has no search backend without `ripgrep`.

The count above is the `brew leaves` set, verified to match this list exactly in
both directions on 2026-09-17. It was previously recorded as 24 while listing 25
entries; corrected. `brew list --formula` returns 134 entries, the full dependency
closure, and is not what `packages.yaml` should declare.

Four more formulae are **declared** in `packages.yaml` without being leaves of the
current install: `chezmoi` (not installed at all, see the bootstrap step in phase
0), `shellcheck` (defect 7), and `atuin` and `bun`, both of which are standalone
installs in `$HOME` that nothing declared. Declared total: 29.

**Homebrew casks (2):** `font-jetbrains-mono-nerd-font`, `opensuperwhisper`

**npm global, pinned under nvm node v24.21.0 (5):** `chrome-devtools-axi`,
`gh-axi`, `lavish-axi`, `quota-axi`, `tasks-axi`

**uv tools (1):** `code-review-graph`

**Standalone binaries in `~/.local/bin`:** `claude`, `herdr` (20 MB),
`treehouse` (12 MB), `uv` (41 MB), `no-mistakes`

`~/.local/bin` also holds `uvx`, `env.fish` and a `code-review-graph` symlink, all
of them written by `uv` rather than installed on their own.

**Installed outside any package manager:** WezTerm, at
`~/Applications/WezTerm.app`. No cask registered, no config yet. Verified
2026-09-17: `atuin` (`~/.atuin/bin/atuin`) and `bun` (`~/.bun/bin/bun`) are in the
same category and were missing from this survey. Both are sourced by `~/.zshrc`,
and `bun` is a hard dependency of the `settings.json` status line
(`bunx -y ccstatusline@latest`), so a fresh machine breaks without it.

**Not installed, and needed first:** `chezmoi`. Verified 2026-09-17:
`command -v chezmoi` returns nothing. Every phase below assumes a working
`chezmoi apply`, so phase 0 gains an explicit bootstrap step.

### Authored configuration

| Path | Size | Handling |
|---|---|---|
| `~/.zshrc` | 827 B | template |
| `~/.zprofile` | 173 B | managed file |
| `~/.config/nvim/` | ~4 KB, 10 files | symlink directory |
| `~/.config/wezterm/` | does not exist yet | symlink directory |
| `~/.config/herdr/config.toml` | 132 B | symlink file |
| `~/.claude/CLAUDE.md` | 1.5 KB | managed file |
| `~/.claude/RTK.md` | 964 B | managed file |
| `~/.claude/settings.json` | 6.2 KB | **merge script** (`modify_`), 13 of 15 keys |
| `~/.claude/hooks/herdr-agent-state.sh` | 3.0 KB | **not versioned**, installed by `herdr integration install` |
| `~/.agents/.skill-lock.json` | 5.2 KB | managed file, drives skill restore |

Total authored surface: about 20 files, under 60 KB.

Corrected 2026-09-17: `~/.config/nvim` holds **10** files, not 7 -
`find ~/.config/nvim -type f` returns `init.lua`, `lazy-lock.json`,
`init.lua.bak`, two files under `lua/` and five under `lua/plugins/`. The lock file
and the backup were not counted.

The repository has **no git remote**. `git remote -v` returns nothing, so phase 6
has nowhere to push a workflow. Creating that repository is a manual step,
recorded in `README.md`.

### Neovim

Restructured on 2026-09-17 from a single `init.lua` into a modular layout.
Neovim 0.12.4. Plugin manager: `lazy.nvim`, pinned by `lazy-lock.json`.

```
~/.config/nvim/
  init.lua                  # two requires, nothing else
  lua/vim_config.lua        # mapleader = space, set before any plugin loads
  lua/plugin.lua            # lazy bootstrap + require('lazy').setup('plugins')
  lazy-lock.json            # pins every plugin to a commit
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
2. **`~/.zshrc` will not survive a fresh machine.** Corrected 2026-09-17: there are
   **two** unguarded sources, not one. `. "$HOME/.local/bin/env"` aborts the shell
   if `uv` is absent, and `. "$HOME/.atuin/bin/env"` does the same if `atuin` is.
   Guard both.
3. **Hardcoded home path.** Corrected 2026-09-17: it appears **twice** in
   `~/.zshrc` (the bun completion test and the dead `claude-mem` alias) and once in
   `~/.zprofile` (the JetBrains Toolbox PATH entry), not three times in `~/.zshrc`.
   Phase 3 therefore covers `.zprofile` as well. Replace with `$HOME` in shell and
   `{{ .chezmoi.homeDir }}` in templates.
4. **Homebrew PATH set twice**, manually in `.zshrc` and via `brew shellenv` in
   `.zprofile`. Keep `brew shellenv` only.
5. **Dead file.** `~/.claude/statusline-command.sh` is unreferenced;
   `settings.json` uses `statusLine.command = "bunx -y ccstatusline@latest"`.
   Do not version it. Delete it.
6. **Hidden cross-repo dependency.** `settings.json` registers a plugin
   marketplace at `<home>/projects/bdk`, a local directory. The `bdk` repo must be
   cloned there or the plugin fails to load. Phase 5 makes this explicit.
7. **`shellcheck` is present by accident.** `CLAUDE.md` requires every script to
   pass it and phase 6 runs it in CI, but `brew uses --installed shellcheck`
   reports `actionlint` as its only dependent and its install receipt says
   `"installed_on_request": false`. It is not a leaf, so a `brew leaves`-derived
   `packages.yaml` would omit it, and removing `actionlint` would silently remove
   the repository's own lint gate. Declare it explicitly in phase 1.
8. **Two skills cannot be restored.** `~/.agents/skills` holds 15 directories but
   `.skill-lock.json` has 13 entries. `create-tasks-workspace` and `no-mistakes`
   have no `sourceUrl`, so phase 5 cannot reproduce them. Its completion criterion
   is 13, not 15, and the two are documented as manual in `README.md`.
9. **The lock file keys are display names, not directory names.** `"Agent
   Development"` corresponds to the directory `agent-development`. A restore script
   that trusts the key verbatim produces `~/.agents/skills/Agent Development`.
   Corrected 2026-09-17: the fix is to *slugify* the key, not to abandon it. Taking
   the directory from `basename(dirname(skillPath))` was the first fix and was
   wrong in one case out of thirteen - see defect 13.
10. **Scripts must target bash 3.2.** macOS ships `/bin/bash` 3.2.57 and Homebrew
   `bash` is not installed. `mapfile`, associative arrays and `${arr[@]}` over an
   empty array under `set -u` are all unavailable. Found by `scripts/check.sh`
   failing with `mapfile: command not found` on its first run.

### Defects found by the first execution

Surveyed 2026-09-17 by installing `chezmoi` and running `init` and `apply` into
throwaway destinations for the first time. These are defects in this repository,
not in the machine it describes, and every one of them failed **silently**: nothing
errored, nothing was red, and the output looked plausible. All five are fixed.

11. **`--promptChoice` is keyed on the prompt text, not on the field it fills.**
   `--promptChoice "profile=managed"` against
   `promptChoiceOnce . "profile" "<text>" …` does not error. The prompt fires, and
   with no TTY the template receives the literal prompt string as the profile.
   Every `eq .profile` branch then goes false and the render still looks sane. The
   flag also takes comma-separated `key=value` pairs, so the original prompt text
   (which contained both a comma and an `=`) could not have been matched under any
   key. All three call sites in CI were affected, so **CI could never have passed**
   - which went unnoticed because the repository has no remote yet and CI has never
   run. Fix: prompt text shortened to `Machine profile`, CI keyed on that string,
   and an assertion added that greps the generated config for the profile it asked
   for.
12. **`chezmoi init --source DIR` does not persist DIR.** The generated config
   held `[data]` and nothing else, so the `chezmoi apply` that README tells you to
   run next resolved its source to `~/.local/share/chezmoi`, found an empty
   directory, and applied nothing. Fix: `.chezmoi.toml.tmpl` writes `sourceDir`
   itself, and the CI apply job runs a bare `apply` with no `--source` to keep it
   honest.
13. **The skill directory name derived from the path renames one skill.**
   `basename(dirname(skillPath))` and the slugified lock file key agree for twelve
   of the thirteen skills. `"Writing Hookify Rules"` lives upstream at
   `plugins/hookify/skills/writing-rules/`, so the path-derived restore installs it
   as `writing-rules`. Fix: slugify the key at template time; CI asserts this one
   case by name.
14. **`run_onchange_` on a script whose text depends on no data runs once, ever.**
   `60-agent-hooks` templated nothing into itself, so its rendered text was
   constant and chezmoi would have executed it exactly once per machine - despite a
   comment in the script claiming the opposite. A tool installed later would never
   get its hook; a tool that upgraded would keep the hook it shipped with. Fix:
   plain `run_after_`, since all five installers are idempotent.
15. **`execute-template --init` supplies neither `[data]` nor `.chezmoidata`.** It
   only makes the `prompt*` functions callable. Every `.profile` and `.packages`
   reference under it errors, which is what the CI lint step was built on. Fix: CI
   generates a real config with `init --config-path` and renders with `--config`.

---

## Phase 0: Repository skeleton

**Goal:** an empty but valid chezmoi source tree, with the profile prompt working.

- [ ] **Bootstrap step, manual and one-off:** `brew install chezmoi`. The engine
      cannot install itself from inside its own run. Added after the 2026-09-17
      survey found `chezmoi` neither installed nor declared anywhere
- [x] `git init`, add `.gitignore` covering `live/**/*.log`, `live/**/*.sock`, `.DS_Store`
- [~] Create `.chezmoiroot` containing `home`
- [~] Create `home/.chezmoi.toml.tmpl` with `promptChoiceOnce` over
      `managed` / `owned`, stored as `.profile`. The prompt text is `Machine
      profile` and must stay short and free of `,` and `=`: it doubles as the
      lookup key for `--promptChoice`, which is how CI answers it (defect 11)
- [~] Have the same template record `sourceDir`. `chezmoi init --source` does not
      persist it, and without it a later bare `chezmoi apply` applies nothing
      (defect 12)
- [~] Add a profile-vs-reality assertion: if `.profile` is `owned`, require admin
      group membership; abort otherwise. Lives in
      `run_once_before_00-assert-profile.sh.tmpl`, not in `.chezmoi.toml.tmpl`:
      the config template is evaluated once at `init`, the assertion must run on
      every apply
- [ ] Run `chezmoi init --source ~/projects/dotfiles` on a real machine and confirm
      the prompt fires exactly once. Partially done 2026-09-17: verified
      non-interactively into a throwaway destination under both profiles, with the
      generated config carrying both the answer and `sourceDir`, and a bare
      `chezmoi apply` afterwards finding the source tree. Never run against a real
      `$HOME`
- [x] `scripts/check.sh`: mechanical guardrails replacing the rules that used to
      sit in `CLAUDE.md` as prose. Verified 2026-09-17 in both directions - clean
      tree exits 0, and a planted script containing `sudo`, `brew bundle
      --cleanup`, a literal `/Users/<name>` path, a missing `set -euo pipefail` and a
      `ghp_` token is caught on all five

**Done when:** `chezmoi data` prints the chosen profile and `chezmoi apply` is a
no-op.

---

## Phase 1: Package inventory

**Goal:** every installed tool is declared in one file, and re-installable.

- [~] Create `home/.chezmoidata/packages.yaml` with the four channels. The profile
      split turned out to apply to casks only - see the decisions log
- [~] Split casks into `user_level` (fonts, installs to `~/Library`) and
      `app_bundle` (needs an appdir override on `managed`)
- [~] `run_onchange_10-brew.sh.tmpl`: render a Brewfile from YAML, run
      `brew bundle install`. **No `--cleanup`, no `--force`.** Corrected: `brew
      bundle` has no `--appdir` flag. The mechanism is `cask_args appdir:` written
      into the Brewfile, emitted only when the profile is `managed`
- [~] `run_onchange_30-npm-global.sh.tmpl`: install the five `*-axi` packages
- [~] `run_onchange_40-uv-tools.sh.tmpl`: bootstrap `uv` if absent, then
      `uv tool install` each entry
- [~] Add WezTerm as a cask
- [ ] Drop the manual `~/Applications/WezTerm.app` install. Manual and one-off:
      `brew install --cask` refuses to write over an app bundle it has no receipt
      for, and `--force` is banned repository-wide. Move the existing bundle to the
      trash once, then apply. Recorded in `README.md`
- [~] Declare `shellcheck` explicitly (defect 7)
- [~] Declare `chezmoi`, `atuin` and `bun` explicitly. Same class of defect as 7:
      installed, depended upon, declared nowhere. `bun` is a hard dependency of the
      `settings.json` status line

**Done when:** a second `chezmoi apply` produces no changes and installs nothing.

**Risk:** low. Nothing is removed. Worst case a package is already present and
`brew bundle` reports it as satisfied.

---

## Phase 2: Configuration files

**Goal:** all authored config lives in the repo, and application-written files
stay editable in place.

- [~] Create `live/` and copy the real files there: `nvim/`, `wezterm/`,
      `herdr/config.toml`
- [~] Add `symlink_*.tmpl` entries pointing at `{{ .chezmoi.sourceDir }}/../live/...`
- [~] Add managed files: `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`
- [~] Handle `~/.claude/settings.json` with a `modify_` merge script rather than a
      copy. Corrected 2026-09-17: the file has three authors, so copying it
      versioned somebody else's output. 13 of its 15 top-level keys are ours;
      `hooks` belongs to five installed tools and `autoMode` to Claude Code.
      Only one templated path remains, the `bdk` marketplace
- [~] Install agent hooks through each tool's own installer
      (`run_after_60-agent-hooks.sh.tmpl`) instead of versioning a copy of herdr's
      script. Plain `run_`, not `run_onchange_`: see defect 14. All five install
      commands were checked against the tools' own `--help` on 2026-09-17
- [~] Write the first WezTerm config in `live/wezterm/wezterm.lua`: JetBrains Mono
      Nerd Font, theme, sensible keybindings
- [~] Delete `~/.claude/statusline-command.sh` - declaratively, via
      `home/.chezmoiremove`. A one-shot `rm` in a `run_once_` script would silently
      do nothing on a machine that had already run it
- [ ] Delete `~/.config/nvim/init.lua.bak` once the new layout has been used for a
      few days and the old single-file config is no longer wanted

### Neovim specifics

Move the whole of `~/.config/nvim` (7 files) into `live/nvim/` and symlink it.
Plugin payloads live in `~/.local/share/nvim/lazy/`, so nothing large follows.

- [~] Commit `lazy-lock.json` together with the config. It pins every plugin to a
      commit and is what makes a fresh machine reproduce this exact setup
- [x] Confirm `ripgrep` and `fd` are in `packages.yaml` before this phase lands.
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

- [~] Port `.zshrc` to a template, fixing defects 1 through 4 from "Current state"
- [~] Port `.zprofile` to a template as well - it carries the third hardcoded home
      path (defect 3, corrected)
- [~] Guard every `source` with an existence test. Two were unguarded, not one
- [~] Keep `brew shellenv` in `.zprofile` as the only PATH entry point for
      Homebrew. It probes both `/opt/homebrew` and `/usr/local`, so the file does
      not assume Apple silicon
- [ ] Verify with `zsh -l -c 'exit'` under a temporary `HOME` where no tools exist

**Done when:** a login shell in an empty `HOME` starts with no errors.

---

## Phase 4: Profiles and git identity

**Goal:** one repo, correct identity and package set on both machines.

- [~] Add `~/.gitconfig` as a template; email switches on `.profile`
- [ ] Confirm the profile-driven split renders correctly for both values
      (`chezmoi execute-template` against each)
- [~] Document in `README.md` how to bootstrap the second machine, and every step
      that stays manual

**Done when:** `chezmoi execute-template` with `profile=managed` produces a
Brewfile containing `cask_args appdir:`, and with `profile=owned` does not.

Corrected 2026-09-17: the original criterion named "admin-only casks", but there
are none. The container formulae were the only profile-split candidate and they are
wanted on both machines. The appdir line is the real divergence, and CI asserts it
in both directions.

---

## Phase 5: Claude agent layer

**Goal:** plugins and skills reproducible on a fresh machine.

- [~] Version `~/.agents/.skill-lock.json`
- [~] Write `run_onchange_after_50-claude-skills.sh.tmpl`: for each entry in the
      lock file, clone `sourceUrl` once per repository and copy `skillPath`'s
      folder into `~/.agents/skills/<folder>`, then symlink into `~/.claude/skills`.
      The folder name is the slugified lock file key, expanded at template time
      (defects 9 and 13). The list is expanded at template time with
      `include … | fromJson`, which removes a runtime `jq` dependency and makes
      `run_onchange` fire on any lock file change
- [~] Make the `bdk` cross-repo dependency explicit: clone
      `<home>/projects/bdk` if missing, over **HTTPS**, or fail with a clear
      message. The repository is public, and an SSH remote made a GitHub key an
      undeclared prerequisite of `chezmoi apply` - which matters doubly because
      this script's failure aborts the apply before the hooks script runs
- [ ] Confirm plugins restore from `settings.json` alone
      (`enabledPlugins` + `extraKnownMarketplaces`), with no need to reproduce
      `installed_plugins.json` or the plugin cache

**Done when:** deleting `~/.agents/skills` and running `chezmoi apply` restores
**13** skills, under the names they have today. Verified 2026-09-17 by rendering
only: all thirteen `sourceUrl` + `skillPath` pairs resolve upstream (checked
through the GitHub contents API) and the thirteen rendered folder names match the
directories on disk exactly. The script itself has still never been executed. Corrected 2026-09-17 from 15: see defect 8. The remaining two have
no source to restore from and are documented as manual in `README.md`.

**Note:** there is no `skills` CLI on this machine. The lock file is written by an
agent-side skill, not a package manager, so restore must be our own script. This
is the phase most likely to need iteration.

---

## Phase 6: CI

**Goal:** prove a fresh machine works, without owning a fresh machine.

- [x] Create the GitHub repository and push `main`. Created public, not private,
      by the owner's decision on 2026-09-17; see the decisions log
- [x] `.github/workflows/test.yml` on `macos-latest`
- [x] Job 1: `./scripts/check.sh`
- [x] Extend Job 1 to shellcheck the `*.sh.tmpl` scripts too, by rendering them
      with `chezmoi execute-template` first - under **both** profiles, because a
      template can be valid on one branch and broken on the other
- [x] Job 2: `chezmoi apply` into a throwaway `HOME` with `profile=managed`, then
      assert the expected symlinks and files exist, plus the `~/.claude` file count
- [x] Job 3: same with `profile=owned`, asserting the profile split diverges. Both
      run from one matrix
- [x] Do not install the full package set in CI; assert the rendered Brewfile
      instead, via `--exclude=scripts`. Installing 29 formulae per run buys little
      and costs minutes
- [x] Rewritten 2026-09-17 after the first local execution. As authored, **no job
      in this workflow could have passed**: all three `--promptChoice` call sites
      used the wrong key (defect 11), the lint job rendered with
      `execute-template --init`, which supplies no data at all (defect 15), `init`
      wrote its config into the runner's real `HOME` rather than the throwaway one
      because `--config-path` was missing, and the `bdk` marketplace assertion
      compared against `$FAKE_HOME` although `.chezmoi.homeDir` does not follow
      `--destination`
- [x] Add assertions for the two defects that produce a plausible-looking result:
      that the profile prompt was actually answered, and that `init` recorded
      `sourceDir`
- [x] Add an assertion that the skill restore keeps `writing-hookify-rules` under
      that name and clones `bdk` over HTTPS (defect 13)

**Done when:** CI is green on GitHub and a deliberately broken template turns it
red. Corrected 2026-09-17: `main` is pushed and all three jobs are green on
`macos-latest`. The negative half is still unverified - nothing has yet confirmed
that a deliberately broken template turns CI red - so the phase stays open on that
one criterion.

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
      method, or accept them as a documented manual step. `atuin` and `bun` were in
      the same category and are now Homebrew formulae; these three are what is left.
      **herdr is the one that costs something today:** this repository symlinks its
      config, installs its hook and restores its skill, but installs nothing. On a
      fresh machine `run_after_60` prints `herdr is not installed, skipping` and
      moves on. `claude` itself is in the same position - the whole agent layer is
      configured for a binary no channel installs.
- [ ] `create-tasks-workspace` and `no-mistakes` have no entry in
      `.skill-lock.json` (defect 8). Find their source, accept them as manual, or
      drop them. Documented as manual for now, which is the honest state rather
      than a decision.
- [ ] The `wezterm` cask in homebrew-core is pinned to a 2024 build. If the
      installed application is newer, decide between the `wezterm@nightly` cask and
      accepting the older stable one. Not resolvable without comparing versions on
      the machine.
- [x] **Resolved.** The container stack stays common to both profiles. Moved to the
      decisions log.
- [x] **Resolved.** WezTerm stays; Ghostty is not adopted. Moved to the decisions
      log. `live/wezterm/wezterm.lua` is written on that basis.
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
| 2026-09-17 | `CLAUDE.md` split three ways: always-loaded invariants, `.claude/rules/*` scoped by path, `scripts/check.sh` for anything mechanical | The file is loaded into every session in this repo and pays its token cost every time. Guidance that only matters while touching one path should load when that path is touched, and a rule a machine can check should not depend on an agent remembering it |
| 2026-09-17 | Mechanical rules moved from prose into `scripts/check.sh` | A prose rule fails silently when ignored; a gate fails loudly. Covers `sudo`, `brew bundle --cleanup/--force`, absolute home paths, the `set -euo pipefail` prologue, shellcheck and a secret tripwire |
| 2026-09-17 | Roadmap discipline moved to `.claude/rules/roadmap-discipline.md`, settings.json sync to `.claude/rules/claude-config-sync.md` | Both are real recurring knowledge, but neither is needed in a session that does not touch those files |
| 2026-09-17 | Facts live in this file only; `CLAUDE.md` carries the rule and a pointer | Sizes and counts decay. `CLAUDE.md` had `1.5 GB`, `5 MB`, `132 B` and an nvm pin duplicated from the survey here, which is two places to update and one to forget |
| 2026-09-17 | "no agent name as co-author" dropped from this repo's `CLAUDE.md` | It is already in the user-level `~/.claude/CLAUDE.md` and applies everywhere. Restating it here buys nothing and costs tokens in every session |
| 2026-09-17 | Scripts target bash 3.2, not bash 4 | macOS ships 3.2.57 and Homebrew `bash` is not installed. A bootstrap script that needs a package manager to run cannot bootstrap the package manager |
| 2026-09-17 | No pre-commit framework; one script invoked by hand and by CI | The direct path has not exposed a blocker yet. Adding a hook manager would be machinery ahead of need |
| 2026-09-17 | `chezmoi` installed by a documented manual `brew install`, and also declared in `packages.yaml` | The engine cannot install itself from inside its own run. Declaring it as well is what makes the second machine converge on one version rather than on whatever the bootstrap happened to fetch |
| 2026-09-17 | `atuin` and `bun` declared as Homebrew formulae rather than left as standalone `$HOME` installs | Same defect as `shellcheck`: depended upon by `.zshrc` and by the `settings.json` status line, declared nowhere. One channel is worth more than preserving two installer scripts |
| 2026-09-17 | Container stack common to both profiles | The four container formulae were the only split candidate and they are wanted on both machines. A split would have been structure without content |
| 2026-09-17 | WezTerm over Ghostty | Inline mermaid in the buffer needs the Kitty graphics protocol, which WezTerm supports only partially. It is a convenience, not a requirement: `<leader>mp` already renders mermaid in the browser. WezTerm is installed and slated for phase 1; swapping terminals to gain in-buffer images is a bigger change than the gain justifies |
| 2026-09-17 | Profiles diverge on `cask_args appdir:`, not on the package list | Phase 4's original criterion assumed admin-only casks. There are none. The appdir override is the real difference and CI asserts it in both directions |
| 2026-09-17 | The skill list is expanded into the restore script at template time, not parsed at runtime | Removes a `jq` dependency, removes the question of whether the lock file has reached the destination yet, and makes the script text change whenever the lock file does - which is exactly what re-triggers `run_onchange` |
| 2026-09-17 | `~/.claude/statusline-command.sh` removed via `.chezmoiremove`, not by a script | A one-shot `rm` in a `run_once_` script silently does nothing on a machine that already ran it. A declarative removal converges |
| 2026-09-17 | Plan split: `docs/IMPLEMENTATION.md` holds the technical design, `docs/ROADMAP.md` keeps all state | An implementation document was wanted, but two files with checkboxes drift apart. Splitting on *how* versus *what state* keeps "one file, one truth" intact without changing the rule |
| 2026-09-17 | The `owned` git email is written into `dot_gitconfig.tmpl` rather than prompted | Chosen explicitly during review. An address is not a secret, and it is already on every commit in the history. Reasoning corrected the same day: the original rationale rested on the repository being private, which it is not. Revisit if a third environment appears: `promptStringOnce` would handle that without a repository change |
| 2026-09-17 | No hook file is versioned; every tool installs its own | Four of the five Claude Code hooks are already just a command name on `PATH`. The fifth, herdr's, was the sole reason `settings.json` needed a second templated path, the sole reason `check.sh` needed an exemption, and would have had `chezmoi apply` revert herdr's own upgrades. `herdr integration status` tracks a version that a copy in git cannot. The declaration moves from a snapshot to an install command, which is the more durable form |
| 2026-09-17 | `settings.json` merged with a `modify_` script, not copied and re-added | It has three authors: this repository, Claude Code and five tools. A copy versions the other two authors' output. `modify_` receives the current file on stdin and writes the merge, so nothing of theirs is ever lost, and the `chezmoi re-add` procedure that the old rule described disappears entirely |
| 2026-09-17 | `autoMode` deliberately not versioned | Claude Code generates it per project. It named a client organisation, its private repository, its services, its protected branches and the environment variables holding its secrets. That is neither toolbox configuration nor this repository's to publish, and it goes stale the moment the project changes |
| 2026-09-17 | History rewritten before the first push to remove `settings.json.tmpl` | The repository had no remote yet, so nothing had been published and the rewrite cost nothing. Purging a blob after a push is a different and much worse problem |
| 2026-09-17 | Phases 0-6 authored without executing anything | Verification will happen on a dedicated test account, so no run on the work machine can be trusted as a fresh-machine test anyway. Checkboxes stay `[~]` until that account has run each "Done when" |
| 2026-09-17 | The `bdk` marketplace is cloned over HTTPS, not SSH | The repository is public, so the SSH remote bought nothing and cost a prerequisite: a GitHub key that a fresh machine does not have. The clone failing aborts `chezmoi apply` before the hooks script runs, so the cheapest transport is the right one |
| 2026-09-17 | `60-agent-hooks` is plain `run_after_`, the only non-`run_onchange_` install script | Its rendered text depends on no data, so `run_onchange_` would have executed it once per machine and never again. The five installers are idempotent and take under a second, so the cost of running them every apply is smaller than the cost of a hook frozen at day-one version |
| 2026-09-17 | The skill directory name is the slugified lock file key, not the upstream path | The two agree for twelve of thirteen skills, which is the worst possible failure shape: a path-derived name quietly renames `writing-hookify-rules` to `writing-rules` and nothing complains. CI now asserts that single case, because it is the only one that can regress |
| 2026-09-17 | The profile prompt text is three words, with the explanation moved to README | The prompt string is also the `--promptChoice` lookup key, and the flag parses comma-separated `key=value` pairs. A descriptive prompt containing a comma and an `=` cannot be answered non-interactively under any key, which is what made CI unrunnable |
| 2026-09-17 | Repository is public, reversing "Repository stays private" earlier the same day | Asked at the point of the first push, with the remote still empty and nothing yet published, and answered by the owner. The tradeoff is unchanged and was accepted rather than missed: the tree enumerates an MDM-managed machine's tooling, names Mosyle, and records that the account has no admin rights. What changes is that the no-secrets rule stops being a precaution and becomes the only thing standing between this repository and publication, so `check.sh`'s secret tripwire is now load-bearing |
