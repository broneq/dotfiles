# Roadmap

Execution plan for this dotfiles repository. Phases are ordered so that every one
of them leaves the machine in a working state. You can stop after any phase.

Phases 0 through 6 are **additive**: they record existing state and bind it to git.
Nothing is uninstalled. Phase 7 is the only destructive one and is deliberately
last.

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done.

`[~]` is the honest state for most of what was written on 2026-09-17. Corrected
three times the same day. The file layer is genuinely fresh-machine tested: it is
applied on `macos-latest` on every push and is green. The install scripts have now
run too, once, in `install.yml` - six of its seven steps passed and the seventh
found two defects. Nothing has yet been applied to a real machine. `chezmoi` was installed on the `managed` machine and `chezmoi init`
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

**Homebrew formulae (23):** `actionlint`, `colima`, `docker`, `docker-buildx`,
`docker-compose`, `fd`, `gh`, `git-filter-repo`, `go`, `graphviz`, `htop`,
`midnight-commander`, `mkcert`, `neovim`, `nvm`, `pandoc`, `poppler`,
`python@3.14`, `ripgrep`, `rtk`, `tree`, `watch`, `whistle`

`ripgrep` and `fd` were added on 2026-09-17 as hard dependencies of the Neovim
picker. Snacks `grep` has no search backend without `ripgrep`.

The count above is the `brew leaves` set of 2026-09-17, verified to match in both
directions that day, minus `beads` and `hey`, dropped on 2026-09-18; see the
decisions log. Both may still be installed on this machine - dropping a
declaration does not uninstall anything, and `--cleanup` is forbidden on
`managed`. `brew list --formula` returns the full dependency closure and is not
what `packages.yaml` should declare.

Four more formulae are **declared** in `packages.yaml` without being leaves of the
current install: `chezmoi` (not installed at all, see the bootstrap step in phase
0), `shellcheck` (defect 7), and `atuin` and `bun`, both of which are standalone
installs in `$HOME` that nothing declared. Declared total: 27.

**Homebrew casks (2):** `font-jetbrains-mono-nerd-font`, `opensuperwhisper`
(replaced by `openwhispr` on 2026-09-18; see the decisions log)

**npm global, pinned under nvm node v24.21.0 (5):** `chrome-devtools-axi`,
`gh-axi`, `lavish-axi`, `quota-axi`, `tasks-axi`

**uv tools (1):** `code-review-graph`

**Standalone binaries in `~/.local/bin`:** `claude`, `herdr` (20 MB),
`treehouse` (12 MB), `uv` (41 MB), `no-mistakes`. Corrected 2026-09-18: `herdr`
is a homebrew-core formula and is declared in `packages.yaml` as of that date;
the `~/.local/bin` copy on the `managed` machine is the `curl | sh` install and
shadows the formula until deleted by hand (see README, bootstrap step 6).

`~/.local/bin` also holds `uvx`, `env.fish` and a `code-review-graph` symlink, all
of them written by `uv` rather than installed on their own.

**Installed outside any package manager:** WezTerm, at
`~/Applications/WezTerm.app`. No cask registered. Corrected 2026-09-18: "no
config yet" was wrong, and the error was load-bearing. A full configuration
existed at `~/.wezterm.lua` - an iTerm2 "Default" profile reproduced by hand -
and WezTerm reads that path *before* `~/.config/wezterm/wezterm.lua`. Its
contents are now `live/wezterm/wezterm.lua` and `home/.chezmoiremove` deletes the
shadowing file. Verified
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
| `~/.config/wezterm/` | ~4 KB, 1 file | symlink directory |
| `~/.config/herdr/config.toml` | 132 B | symlink file |
| `~/.config/ccstatusline/settings.json` | 2.0 KB | symlink file |
| `~/.claude/CLAUDE.md` | 1.5 KB | managed file |
| `~/.claude/RTK.md` | 452 B | **not versioned**, written by `rtk init --global` |
| `~/.claude/settings.json` | 6.2 KB | **merge script** (`modify_`), 13 of 15 keys |
| `~/.claude/hooks/herdr-agent-state.sh` | 3.0 KB | **not versioned**, installed by `herdr integration install` |
| `~/.agents/.skill-lock.json` | 5.2 KB | managed file, drives skill restore |

Total authored surface: about 21 files, under 60 KB.

`~/.config/ccstatusline/settings.json` was added on 2026-09-18. It holds the
whole three-line status line - git root, branch, model, context bar, session and
weekly usage with their reset timers, version, free memory - and was the only
half of `statusLine` not versioned: `settings.json` declared the command,
nothing declared what the command renders.

Corrected 2026-09-17: `~/.config/nvim` holds **10** files, not 7 -
`find ~/.config/nvim -type f` returns `init.lua`, `lazy-lock.json`,
`init.lua.bak`, two files under `lua/` and five under `lua/plugins/`. The lock file
and the backup were not counted.

The remote is `git@github.com:broneq/dotfiles.git`, public, added on 2026-09-17.
The survey above predates it and recorded no remote.

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

### Defects found by the first install run

Surveyed 2026-09-17 from the first `install.yml` run, which is the first time any
install script executed anywhere. Six of its seven steps passed: `brew bundle` with
29 formulae and 3 casks, `WezTerm.app` landing in the right directory under both
profiles, the npm globals resolving under nvm, the uv bootstrap, and the skill
restore. The hooks step failed, and took two defects with it. Both, again, produce
a zero exit and a reassuring message.

16. **`rtk init --global` asks a question and answers it `N`.** With no TTY it
   prints "Patch existing settings.json? [y/N]", defaults to no, prints a MANUAL
   STEP block for a human to paste, and **exits 0**. The hooks script recorded
   `hook: rtk` and no hook existed. Feeding `y` on stdin does not help - rtk
   detects the non-interactive session, not the empty terminal. Fix: the
   `--auto-patch` flag, verified idempotent and non-destructive to the other
   authors' keys.
17. **The hooks script did not source nvm.** `gh-axi` and `chrome-devtools-axi`
   are npm globals under the nvm-managed node, which is not on `PATH` during a
   non-interactive `chezmoi apply`. Both were reported as
   "not installed, skipping", a line indistinguishable from the legitimate herdr
   one. Fix: source nvm the way `30-npm-global` does, before the installers run.
   Verified locally by running scripts 30 and 60 in sequence with `PATH` stripped
   of every nvm directory.

   The same assignment pattern in `30-npm-global` carried a latent version of this:
   under `set -e`, `nvm_sh="$(brew --prefix 2>/dev/null)/..."` takes brew's exit
   status, so a missing brew aborted the script instead of reaching the actionable
   message below it. Guarded in both.

### Defects found by the second install run

Surveyed 2026-09-18. The fix for defect 17 copied the nvm block from
`30-npm-global` and dropped one line of it, which turned the next `install.yml`
run red on the same step. The first defect here is the only one in this document
that failed **loudly**, and it is the cheaper kind for exactly that reason.

18. **The hooks script sourced nvm without exporting `NVM_DIR` first.** Homebrew's
   `nvm.sh` shim opens with `[ -z "$NVM_DIR" ] && export NVM_DIR="$HOME/.nvm"`,
   an unbound dereference under `set -u`, so the source line aborted the script
   with `NVM_DIR: unbound variable` and `chezmoi apply` exited 1. `30-npm-global`
   exports the variable one line above its own nvm block; the copy into
   `60-agent-hooks` left it behind. This cannot reproduce in an interactive shell,
   where `.zshrc` exported `NVM_DIR` long before, which is why the block looked
   fine when it was tested by hand. Fix: the export, plus check 7 in
   `scripts/check.sh` - any file that names `opt/nvm/nvm.sh` must export `NVM_DIR`
   on an earlier line. Two mutations in `check-negative.sh` cover both halves, the
   missing export and one placed too late.

   Writing that check tripped the same `set -e` trap defect 17 records: the
   `exp_line=$(grep -n …)` lookup carries grep's exit status, and a missing export
   is precisely what the check exists to find, so the gate died instead of
   reporting. The negative control is what surfaced it - the gate failed with the
   wrong message rather than the right one. Guarded with `|| true`.

### Defects found by the first apply on the `owned` machine

Surveyed 2026-09-18, from the scrollback of the first real `chezmoi apply` on the
personal Mac and the one that followed it. CI had passed twice by then; every item
here is something a fresh runner cannot see, either because the runner has no
prior state or because it never runs apply a second time.

19. **`~/.claude/RTK.md` was versioned, and it is rtk's file.** `rtk init --global`
   writes it and `run_after_60` calls `rtk init` on every apply. The copy in git was
   rtk's own text from an older release; rtk 0.49 overwrote it seconds after
   chezmoi wrote it, and the next apply stopped with
   "`.claude/RTK.md` has changed since chezmoi last wrote it?", which without a TTY
   is a hard exit. The first apply on any machine could never show this, and CI
   applies once. Fix: the file is not versioned; the `@RTK.md` line stays in
   `CLAUDE.md` because rtk checks for it before appending its own. Verified in an
   empty `HOME`: `rtk init --global --auto-patch` produces `RTK.md`, the
   `settings.json` hook and the `CLAUDE.md` reference, nothing else under
   `~/.claude`.
20. **The nvm default alias was `lts/*`, so `.zshrc` took its slow path on every
   shell.** `30-npm-global` runs `nvm install --lts` on a machine with no node, and
   that command writes `default -> lts/*`. The `.zshrc` block resolves the alias
   by globbing `~/.nvm/versions/node/v<alias>*`, which `lts/*` cannot match, so
   every shell fell through to `nvm use`: 0.32 s startup against 0.08 s with a bare
   major in the file, measured three times each. The block's comment claimed a
   bare major "on both machines", which was true of the machine where it was
   written and of nothing the script produced. Fix: `30-npm-global` pins the alias
   to the installed major after the install line, idempotently.
21. **`scripts/check-templates.sh` failed on any initialised machine.**
   `promptChoiceOnce` reads its answer from the config file at the default
   location before it consults `--promptChoice`, and `--config-path` pointing
   elsewhere does not stop it. On a machine whose `~/.config/chezmoi/chezmoi.toml`
   says `owned`, the `managed` pass rendered as `owned` and the guard added for
   defect 15 caught it - correctly, and on every run, so the gate was red by
   design everywhere except CI, whose `HOME` is empty. Fix: the `init` call runs
   under `HOME="$tmp/home-$profile"`.
22. **`herdr is not installed, skipping` was the honest output of a declared gap.**
   The open question said "find the upstream install method"; herdr.dev documents
   `brew install herdr` beside the `curl | sh` route, and homebrew-core carries the
   formula at 0.9.1. Declared in `packages.yaml`. CI now asserts its hook alongside
   the other four instead of excusing its absence.
23. **Every hook installer failed on every apply since `ccb0b38`.** The refactor
   that moved the installer list into `packages.yaml` gave `install_hook` a
   `shift` to separate the tool from its arguments, then ran `"$@"` without
   putting the tool back: the command executed was `integration install claude`,
   not `herdr integration install claude`. All five printed `failed to install
   its hook` and the script exited 0, so `chezmoi apply` still reported success.
   The hooks already on this machine masked it; a fresh machine would have got
   none, and only the weekly `install.yml` would have said so. Found by reading
   the scrollback of the apply that installed `openwhispr`. Fix: `"$tool" "$@"`.

Four more things in that scrollback are the machine's, not the repository's, and
are recorded here only so nobody hunts for them in the scripts: a shell with
`/opt/homebrew/Cellar/node/24.7.0/bin` exported by hand, which broke every
`#!/usr/bin/env node` hook the moment `brew` upgraded `simdjson` under it; a
root-owned `/opt/homebrew/lib/node_modules/npm` from a `sudo npm i -g` in 2025,
which fails `brew postinstall node`; a `dicklesworthstone/tap` left behind by the
dropped `beads`; and two user-level MCP servers in `~/.claude.json` (`serena`,
`codegraph`) pointing at binaries that are not there.

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
      `herdr/config.toml`, `ccstatusline/settings.json`. The last was added
      2026-09-18: `settings.json` declared the status line *command* and nothing
      declared what that command renders, so a fresh machine got ccstatusline's
      default layout
- [~] Add `symlink_*.tmpl` entries pointing at `{{ .chezmoi.sourceDir }}/../live/...`
- [~] Add managed files: `~/.claude/CLAUDE.md`. Corrected 2026-09-18: `RTK.md`
      was listed here and versioned, but `rtk init --global` writes it; the copy
      in git was rtk's own text from an older release. Dropped, see defect 19
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
- [~] Move both addresses into `.chezmoidata/identity.yaml`, so the machine
      default and the `private` profile override cannot drift apart
- [ ] Confirm the profile-driven split renders correctly for both values
      (`chezmoi execute-template` against each)
- [~] Document in `README.md` how to bootstrap the second machine, and every step
      that stays manual
- [~] Version the `git-identity` layer: the `private` profile registry as a
      `modify_` merge, its gitconfig as a template, the plugin as an
      `enabledPlugins` entry. `~/.config/gh-private` stays out; see the decisions
      log
- [ ] Confirm on the second machine that `/git-identity:use private` binds a
      project and `git config user.email` follows, after the manual `gh auth login`
      documented in `README.md`

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
      `installed_plugins.json` or the plugin cache. Established 2026-09-18 from
      Claude Code 2.1.275 itself, which carries the strings
      `Syncing installed_plugins.json with enabledPlugins from all settings.json
      files`, `Failed to roll back enabledPlugins after install failure for` and a
      `plugin prune` that removes *auto-installed* plugins - so declaring is
      installing. Still unchecked because that is evidence about the binary, not a
      fresh-machine run, which is what this box asks for. CI now asserts the
      weaker invariant that no enabled plugin comes from an undeclared marketplace

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

### Phase 6b: tests that confirm something

The suite above was thirteen assertions of which three carried signal; the rest
restated that chezmoi works. This closes that gap and the phase's negative
criterion.

- [x] Move the template render out of the workflow into
      `scripts/check-templates.sh`, so it can be run by hand and planted against
- [x] `scripts/check-negative.sh`: eight mutations plus a clean-tree control.
      Each asserts the exit status **and** the message, because exit 1 can come
      from any of the six checks. Verified in both directions on 2026-09-17:
      every mutation is caught, and neutering one check in `check.sh` turns the
      suite red on exactly that case
- [x] Two of those mutations are broken templates, one rendering into invalid
      shell and one failing to render. **This is the phase's negative criterion**
- [x] Run every job against `env HOME="$fake"` instead of `--destination`. The
      install scripts address the machine through `$HOME`, so nothing else can
      ever execute them; it also un-circularises the `bdk` path assertion, which
      was comparing `.chezmoi.homeDir` against the runner's own home
- [x] Seed the destination with a `settings.json` carrying `hooks`, `autoMode`,
      a foreign key and a colliding `model`. On an empty `HOME` the half of
      `modify_settings.json.tmpl` that preserves other authors never ran
- [x] Assert a second apply changes nothing, and that the merged `settings.json`
      is byte-identical across applies
- [x] Assert the git identity actually switches, by comparing against the other
      profile's render rather than a literal address
- [x] Execute the skill restore rather than grepping its rendered text: thirteen
      directories with `SKILL.md`, thirteen resolving symlinks, the `bdk` clone
- [x] Check every declared package name against its registry: `brew info`,
      `brew info --cask`, `npm view`, the PyPI API. Seconds, installs nothing,
      and catches the typo that today only surfaces mid-`brew bundle`
- [x] `-e` as well as `-L` on every symlink assertion; a link to nothing passed
- [x] `.github/workflows/install.yml`: weekly and on demand, no
      `--exclude=scripts`, on a runner that is genuinely a clean Mac
- [x] First run, 2026-09-17. Six of seven steps green on both profiles, which is
      the first evidence that the install path works at all. The hooks step found
      defects 16 and 17
- [ ] Green `install.yml` after the fixes for defects 16 and 17

**Done when:** CI is green on GitHub and a deliberately broken template turns it
red. Corrected twice on 2026-09-17: `main` is pushed, the fast workflow is green on
`macos-latest`, and the negative half is covered by `check-negative.sh` rather than
by nothing. The phase stays open on one item: `install.yml` has run once and found
two real defects, so it has yet to be green.

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
- [ ] `treehouse` and `no-mistakes` are standalone binaries in `~/.local/bin`
      with no declared installer. Find their upstream install method, or accept
      them as a documented manual step. `atuin`, `bun` and `herdr` were in the
      same category and are now Homebrew formulae; these two are what is left.
      `claude` itself is in the same position - the whole agent layer is
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
| 2026-09-17 | Every CI job runs against `env HOME="$fake"`, not `--destination` | The install scripts address the machine through `$HOME`, so a job that only moves the destination can never execute them - which is why they had never run anywhere. It also un-circularises the `bdk` path assertion: `.chezmoi.homeDir` does not follow `--destination`, so that check was comparing the runner's own home against itself |
| 2026-09-17 | `scripts/check-negative.sh` mutates a throwaway clone and asserts the message, not just the exit status | A gate passing on a clean tree is not evidence; one with every check accidentally disabled passes identically. Exit 1 alone is not evidence either, because it could come from any of the six checks, so a mutation tripping the wrong one would read as a pass. Verified in both directions: neutering one check turns the suite red on exactly that case |
| 2026-09-17 | The template render moved from the workflow into `scripts/check-templates.sh` | Twenty lines of bash inside YAML cannot be run by hand, which contradicts "everything mechanically checkable lives in scripts/", and cannot be planted against by a negative test. Kept separate from `check.sh` because that one has to run on a machine where chezmoi is not installed yet |
| 2026-09-17 | The heavy install test is a separate weekly workflow, not a step in the fast one | Tens of minutes against seconds. Merging them makes the fast gate slow and the slow gate noisy. Weekly plus `workflow_dispatch` also means upstream regressions - a renamed formula, changed installer arguments - surface on their own rather than waiting for someone to remember |
| 2026-09-17 | CI asserts each hook is present in `settings.json`, not that its installer exited 0 | Three of the five installers can succeed while installing nothing: rtk answers its own prompt with N and exits 0, and the two npm globals are simply absent from a non-interactive `PATH`, which reads identically to the legitimate herdr skip. An exit-status check would have passed on all three |
| 2026-09-18 | `beads` and `hey` dropped from `packages.yaml` | Neither is used. `beads` is an issue tracker nothing in this toolbox invokes and `hey` an HTTP load generator with no current need. A declared package is a promise to reinstall it on every fresh machine; the cheapest time to stop making that promise is before the second machine exists. Removing the declaration does not uninstall either one - `--cleanup` stays forbidden on `managed`, so the live machine is left as it is |
| 2026-09-18 | Plugins stay declared in `settings.json`; no `claude plugin install` step | `extraKnownMarketplaces` plus `enabledPlugins` already is the install mechanism - Claude Code syncs `installed_plugins.json` against every settings.json on startup and installs what is missing. A script calling the CLI would duplicate the declaration imperatively, and the CLI's own output (`installed_plugins.json`, `known_marketplaces.json`: absolute install paths, commit SHAs, timestamps) is runtime state this repository must not version |
| 2026-09-18 | `enabledPlugins` cut to `bdk` and `caveman` | Dropped: `skill-creator`, `frontend-design`, `elements-of-style` and the two already-disabled entries. It also closed a latent defect rather than fixing it: `elements-of-style@superpowers-marketplace` was enabled while `superpowers-marketplace` was registered only in `~/.claude/plugins/known_marketplaces.json`, runtime state that no fresh machine has, so that plugin could never have installed on the second Mac. With it gone, `extraKnownMarketplaces` needs only the two marketplaces the two surviving plugins come from |
| 2026-09-18 | A plugin is removed from the machine by hand, not by the merge script | jq's `*` adds and overwrites keys and never deletes one, so every plugin dropped above stays installed and enabled on this Mac until `claude plugin uninstall` runs. The alternative - having the script compute the exact `enabledPlugins` and overwrite it - would mean this repository asserting authority over a key Claude Code's own UI also writes, which is the failure the merge exists to avoid. So the divergence is accepted and recorded instead: the declaration is what a fresh machine gets, the live machine is converged by hand |
| 2026-09-18 | `~/.config/ccstatusline/settings.json` symlinked into `live/`, not managed | ccstatusline is configured through its own TUI, which rewrites the file whole, `id` UUIDs and all. A managed file would revert every change made the way the tool expects. Same category as `~/.config/herdr/config.toml`. Accepted cost: the regenerated UUIDs make diffs noisier than the edit that caused them |
| 2026-09-18 | `git-identity` versioned as a plugin declaration plus two files under `~/.config/git-identity`, and nothing else | The plugin comes from the `bdk` marketplace already declared in `extraKnownMarketplaces`, and ships its own `SessionStart` hook, so enabling it is one `enabledPlugins` key and no script. What a fresh machine cannot derive is the registry and the per-profile gitconfig - both are declarations a human curates, both carry absolute home paths, so both are templates rather than copies |
| 2026-09-18 | `~/.config/gh-private` is never versioned | `hosts.yml` is written by `gh auth login` and the token it refers to lives in the login keychain, which this repository does not and must not reproduce. Committing it gives the second machine a file asserting an authenticated session that does not exist: `gh` then reports a login instead of offering one, and every call returns 401. `config.yml` is `gh`'s own generated file, rewritten with a fresh comment banner on upgrades, and holds one authored line (`aliases.co`); the default `~/.config/gh` is unmanaged for the same reason, and managing only the private twin would be an asymmetry with no payoff. The login is a manual bootstrap step in `README.md`, alongside the other five |
| 2026-09-18 | `profiles.json` merged by `modify_profiles.json.tmpl`, not managed outright | Same two-author shape as `settings.json`: this repository declares `private`, while `/git-identity:profile-add` may add a client or second-account profile on one machine only. A managed file would delete those on the next apply, and silently - the gh config directory and the profile gitconfig both survive, so the only symptom is `/git-identity:use` reporting that a profile which plainly exists does not |
| 2026-09-18 | Commit addresses moved into `.chezmoidata/identity.yaml` | `dot_gitconfig.tmpl` and `private.gitconfig.tmpl` need the same personal address. Two literals that must agree, changed months apart, produce commits attributed to a stale address in exactly the projects bound to a profile - and nothing reports it. Same argument, and the same file location, as `packages.yaml` |
| 2026-09-18 | `check-templates.sh` globs `modify_*.tmpl` instead of naming them | The list had one entry and gained a second. A `modify_` script that no gate renders is a script whose first execution is on the machine, against the real file it was written to protect |
| 2026-09-18 | `~/.wezterm.lua` removed via `.chezmoiremove`, its contents merged into `live/wezterm/wezterm.lua` | WezTerm resolves `~/.wezterm.lua` before `~/.config/wezterm/wezterm.lua` and stops at the first hit. The symlink this repository creates was therefore inert: apply succeeded, `chezmoi diff` was empty, and the terminal kept the unversioned file. Two configurations also drifted - a fix had to be written twice to reach both machines |
| 2026-09-18 | WezTerm keeps the hand-built iTerm2 palette; the Dracula scheme is dropped | The stated reason for Dracula was one palette across the window, but herdr emits its own Dracula in truecolor (`38:2::` throughout its output) and never reads the terminal's ANSI palette. A scheme here would only recolour the shell, `ls`, `git` and Neovim, against a background that was chosen deliberately |
| 2026-09-18 | Dim text (SGR 2) given an explicit colour through `font_rules` | WezTerm implements `Intensity=Half` by substituting a lighter face and leaving the colour alone. JetBrains Mono ships ExtraLight, so Claude Code's input suggestion rendered at full foreground and read as text already typed. The rules pin the regular weight and set `foreground` to the foreground blended halfway into the background. Note for whoever edits this next: `foreground` belongs to the `TextStyle` that `wezterm.font*` returns, not to the attributes table passed into it, which discards unknown keys without an error |
| 2026-09-18 | `herdr` is a Homebrew formula, not a manual step | Upstream documents `brew install herdr` as a first-class route and homebrew-core carries it. Moving from the open question closes the only case where this repository configured a tool it did not install: the config symlink, the hook installer and the skill restore all had a binary to point at only if a human had run `curl \| sh` first. The `managed` machine's `~/.local/bin/herdr` must go by hand, because `~/.local/bin` precedes the Homebrew prefix on `PATH` |
| 2026-09-18 | `~/.claude/RTK.md` is not versioned | It is written by `rtk init --global`, which this repository runs on every apply. Same category as the hooks: a vendored copy tracks nothing and loses to the tool on the next run, and here it also made the second apply fail. Defect 19 |
| 2026-09-18 | `30-npm-global` pins the nvm default alias to a bare major | `nvm install --lts` writes `lts/*`, which the `.zshrc` fast path cannot expand; the fallback costs 0.24 s per shell and per subshell. The script already chooses the version, so it also records it in the form the shell can read without nvm. Defect 20 |
| 2026-09-18 | `opensuperwhisper` replaced by `openwhispr` | Both are local voice-to-text dictation apps; `openwhispr` is the one now in use, and two dictation apps bound to hotkeys on one machine is one too many. Same shape as the `beads` decision: the declaration changes, the live machine does not - `--cleanup` stays forbidden on `managed`, so `opensuperwhisper` is removed by hand with `brew uninstall --cask opensuperwhisper` |
