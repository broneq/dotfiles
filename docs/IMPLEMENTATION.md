# Implementation

How the source tree is put together: what each file does, why it is shaped that
way, and which traps it avoids.

**This file carries no status.** No checkboxes, no dates, no progress. State lives
in `docs/ROADMAP.md` and nowhere else. If you find yourself wanting to write "done"
here, the sentence belongs in the roadmap instead.

---

## Layout

```
.chezmoiroot                 -> "home": chezmoi's source is home/, not the repo root
home/
  .chezmoi.toml.tmpl         profile prompt and sourceDir, evaluated at `chezmoi init`
  .chezmoidata/packages.yaml the only place package names appear
  .chezmoiremove             paths chezmoi deletes from the destination
  .chezmoiscripts/           install scripts, never part of the file tree
  dot_zshrc.tmpl             \
  dot_zprofile.tmpl           |  human-authored files: chezmoi owns them
  dot_gitconfig.tmpl          |
  dot_claude/…                |
  dot_agents/…               /
  dot_config/symlink_*.tmpl  links pointing back into live/
live/                        real files the applications rewrite in place
scripts/check.sh             mechanical guardrails, run locally and in CI
.github/workflows/test.yml   CI
```

`.chezmoiroot` exists so that `live/`, `scripts/` and `docs/` can sit at the repo
root without chezmoi trying to install them into `$HOME`. One consequence worth
remembering: `{{ .chezmoi.sourceDir }}` resolves to `<repo>/home`, which is why
every symlink target starts with `../live`.

## The two file categories

Decided by **who writes the file**, not by what it contains.

**Symlink into `live/`** when the application rewrites the file and those edits
should land in git: `~/.config/nvim`, `~/.config/wezterm`,
`~/.config/herdr/config.toml`. chezmoi creates a symlink; editing either path
touches the same bytes, with no `chezmoi apply` round trip.

The symlink source file's *content* is the link target:

```
home/dot_config/symlink_nvim.tmpl   ->  {{ .chezmoi.sourceDir }}/../live/nvim
```

**chezmoi-managed file or template** when only a human writes it: `.zshrc`,
`.zprofile`, `.gitconfig`, `dot_claude/CLAUDE.md`, `dot_claude/RTK.md`, the herdr
hook.

**Merge into, never copy over**, when a file has more than one author.
`~/.claude/settings.json` is the only one, and it has three: this repository,
Claude Code, and five installed tools. `modify_settings.json.tmpl` receives the
current file on stdin and writes the merged result to stdout, so chezmoi never
overwrites what the other authors put there. `.claude/rules/claude-config-sync.md`
has the key-by-key split.

### Hooks belong to their tools

Not one hook file is versioned. Four of the five Claude Code hooks are installed
by a bare command on `PATH` - `atuin hook install claude-code`, `rtk init --global`,
`gh-axi setup hooks`, `chrome-devtools-axi setup hooks` - with nothing on disk to
reproduce. The fifth, herdr,
ships a script, and that one file was the source of four separate problems: it
forced an absolute path into `settings.json`, it is vendor-managed so
`chezmoi apply` would revert herdr's own upgrade, it is POSIX `sh` and could not
satisfy the `pipefail` prologue rule, and it carries a version
(`HERDR_INTEGRATION_VERSION`) that a copy in git cannot track.

herdr installs it itself, and knows whether it is current:

```
$ herdr integration status
claude: current (v10) (~/.claude/hooks/herdr-agent-state.sh)
```

So `run_after_60-agent-hooks.sh.tmpl` calls each tool's own installer instead. The
declaration did not disappear, it changed form: `packages.yaml` says which tools
exist, the script says how each one installs its hook, and both are executable
rather than a snapshot.

This one script is `run_after_`, not `run_onchange_after_`, and it is the only
exception in the tree. A `run_onchange_` script re-runs when its own rendered text
changes, and this script's text depends on nothing - not on `packages.yaml`, not on
the lock file. It would have executed exactly once in the lifetime of a machine: a
tool installed later would never get its hook, and a tool that upgraded would keep
serving the hook it shipped with on day one, which is the precise failure the
"hooks belong to their tools" decision was meant to avoid. All five installers are
idempotent and cheap, so they run on every apply.

### Whitelisting, never directory-adding

`~/.claude` holds `projects/` (1.5 GB), `plugins/` (53 MB) and `jobs/` (33 MB).
Three files land there from this repository: `CLAUDE.md` and `RTK.md` as copies,
and `settings.json` as a merge. The CI apply job asserts that count, so adding a
fourth is a deliberate act that fails the build until the assertion is updated.

`~/.config/nvim` and `~/.config/wezterm` are the exception: both are clean.
Neovim keeps plugin payloads in `stdpath("data")`, outside the config directory,
which is why the whole directory can be symlinked.

## Profiles

`promptChoiceOnce` in `.chezmoi.toml.tmpl` asks once and stores the answer.
Nothing derives the profile from the hostname.

`run_once_before_00-assert-profile.sh.tmpl` validates the answer against
`dsmemberutil checkmembership`. `owned` without admin membership aborts; `managed`
on an admin account only warns, because `managed` never does more than `owned`.

The check lives in a script rather than in `.chezmoi.toml.tmpl` because the config
template is evaluated once at `init`, and the assertion should run on every apply.

**What actually differs between profiles:**

| | `managed` | `owned` |
|---|---|---|
| `cask_args appdir:` in the Brewfile | `~/Applications` | absent |
| git email | work | personal |
| formulae | identical | identical |

The formula list does not split. Four container formulae were the only candidates
and they are wanted on both machines, so a split would be structure without
content.

## Packages

`home/.chezmoidata/packages.yaml` is the single source. Scripts consume it and
contain no package names.

Three entries are there for reasons that are not obvious from the list:

- **`chezmoi`** - the engine cannot install itself from inside its own run, so the
  README documents a manual `brew install chezmoi`. Declaring it here is what makes
  the second machine converge on the same version afterwards.
- **`shellcheck`** - `scripts/check.sh` gates on it, but it was installed only as a
  dependency of `actionlint`. Removing `actionlint` would have silently removed
  this repository's own lint gate. Transitive presence is not a declaration.
- **`bun`** - `settings.json` runs `bunx -y ccstatusline@latest`. Without bun the
  Claude Code status line breaks on a fresh machine, with no hint as to why.

`atuin` joins them for the same reason: `.zshrc` sources it, nothing declared it.

### Install scripts

| Script | Notes |
|---|---|
| `run_onchange_10-brew.sh.tmpl` | Renders a Brewfile into a heredoc and runs `brew bundle install`. `brew bundle` has **no** `--appdir` flag - `cask_args appdir:` inside the Brewfile is the mechanism. Never `--cleanup`, never `--force`. |
| `run_onchange_30-npm-global.sh.tmpl` | Sources nvm explicitly. Installing under whichever node is first on PATH would scatter the five tools across the two or three node installations this machine has. |
| `run_onchange_40-uv-tools.sh.tmpl` | Bootstraps `uv` if absent. The `curl \| sh` in the guarded branch is the only downloaded script in the repository. |
| `run_onchange_after_50-claude-skills.sh.tmpl` | See below. |
| `run_after_60-agent-hooks.sh.tmpl` | Calls each tool's own hook installer. Plain `run_`, not `run_onchange_`; see "Hooks belong to their tools". |

`run_onchange_` re-runs when the script's own text changes. Because the package
list is templated into the script body, editing `packages.yaml` changes the text
and re-triggers the run. Nothing hashes anything explicitly.

The corollary is the trap: a `run_onchange_` script whose text depends on no data
runs once and never again. `60-agent-hooks` is that case and is plain `run_`.

## Skill restore

The lock file `~/.agents/.skill-lock.json` is written by an agent-side skill, not
by a package manager, so restore is ours to write. Three details decide the shape
of the script:

1. **The lock file's keys are display names.** `"Agent Development"` maps to the
   directory `agent-development`, so the key is lowercased and spaces become dashes
   at template time. Deriving the name from `basename(dirname(skillPath))` instead
   looks equivalent and agrees for twelve of the thirteen skills, which is why the
   thirteenth went unnoticed: `"Writing Hookify Rules"` lives upstream at
   `plugins/hookify/skills/writing-rules/`, and a path-derived restore silently
   renames the installed skill to `writing-rules`. CI asserts this one case.
2. **Four of the thirteen skills live in `anthropics/claude-code`.** Cloning per
   skill would fetch the same repository four times, so clones are cached per URL
   for the duration of the run.
3. **The list is expanded at template time,** via `include … | fromJson`. That
   removes a runtime `jq` dependency and removes the ordering question of whether
   the lock file has been written to the destination yet. It also means the script
   text changes when the lock file changes, which is what makes `run_onchange` fire.

The script is `after_` so it runs once the file tree is in place. It also clones
`~/projects/bdk` if missing: `settings.json` registers a plugin marketplace at that
local path, and without it every bdk plugin fails to load with an error that does
not name the cause. The clone is HTTPS even though the repository is the author's
own: the repository is public, and an SSH remote would have made a GitHub key an
undeclared prerequisite of `chezmoi apply` on a machine that has none yet. That
mattered more than it looks, because this script's failure aborts the apply before
the hooks script runs.

Thirteen of the fifteen skills on disk are covered. `create-tasks-workspace` and
`no-mistakes` have no lock entry and therefore no source; they are documented as
manual in the README rather than silently dropped.

## Shell

`.zprofile` is the only place Homebrew's environment is set, via `brew shellenv`.
`.zshrc` used to set `/opt/homebrew/bin` on PATH as well, which silently reordered
PATH on every new shell.

Everything in `.zshrc` that reaches outside the file is guarded by an existence
test, because the file must survive a machine where nothing is installed yet. The
uv and atuin env files are the two that previously aborted the shell outright.

`$HOMEBREW_PREFIX` is used instead of a literal `/opt/homebrew` so the file does
not assume Apple silicon. `.zprofile` probes both prefixes.

## Two chezmoi flags that fail silently

Both of these were wrong in CI for as long as CI existed, and neither announced
itself. They are documented here because nothing mechanical can catch them.

**`--promptChoice` is keyed on the prompt text, not on the field it fills.**
`promptChoiceOnce . "profile" "Machine profile" …` is answered by
`--promptChoice "Machine profile=owned"`. Passing `--promptChoice "profile=owned"`
does not error: the prompt fires, finds no TTY, and the template receives the
literal string `Machine profile` as the profile. Every `eq .profile "owned"` branch
then goes false and the render looks plausible. The flag takes comma-separated
`key=value` pairs, so the prompt text must also contain no comma and no `=` - which
is why the prompt is three words and the explanation lives in the README.

**`execute-template --init` only makes the `prompt*` functions callable.** It feeds
back neither the config template's `[data]` nor `.chezmoidata`, so `.profile` and
`.packages` are both absent under it. To render a script template the way a real
machine renders it, generate a config with `chezmoi init --config-path` first and
pass it with `--config`. CI does exactly that.

**`chezmoi init` does not persist `--source`.** The generated config records the
profile and nothing else unless the template writes `sourceDir` itself, so a later
bare `chezmoi apply` falls back to `~/.local/share/chezmoi`, finds an empty
directory and applies nothing at all. `.chezmoi.toml.tmpl` writes `sourceDir` for
that reason, and the CI apply job runs a bare `apply` to keep it honest.

## Portability

Every script targets **bash 3.2**, which is what macOS ships. Homebrew `bash` is
not installed, and a bootstrap script that needs a package manager to run cannot
bootstrap the package manager.

That rules out `mapfile`, associative arrays, and `${arr[@]}` over a possibly
empty array under `set -u`. The working pattern is a temp file plus
`while IFS= read -r`, as in `scripts/check.sh`.

## What CI proves

`scripts/check.sh` covers the mechanical rules on tracked files. CI adds the two
things it cannot do locally:

- **Rendered templates are shellchecked.** `check.sh` skips `*.sh.tmpl` because a
  chezmoi template is not valid shell until rendered, and says so in its output.
  CI renders each one under **both** profiles first - a template can be fine on one
  branch and broken on the other.
- **A full apply into a throwaway `HOME`,** under both profiles, with
  `--exclude=scripts`. Installing 29 formulae per run buys nothing and costs
  minutes; the rendered Brewfile is asserted directly instead. The apply runs
  without `--source`, so it passes only if `init` recorded `sourceDir`.
- **That the profile prompt was actually answered.** The generated config is
  grepped for the profile the matrix asked for. Without that assertion, the
  `--promptChoice` trap above turns every profile-dependent branch off and the
  remaining assertions still pass.

The apply job also asserts the `~/.claude` file count, which is the standing guard
against the 1.5 GB accident, and the one skill whose directory name the lock file
and the upstream path disagree on.

One thing CI does **not** cover: the install scripts themselves. `--exclude=scripts`
means `brew bundle`, the npm globals, the uv tools, the skill clones and the hook
installers are rendered and shellchecked but never executed. Their first real run is
on a machine.
