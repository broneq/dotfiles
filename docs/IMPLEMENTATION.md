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
  .chezmoi.toml.tmpl         profile prompt, evaluated once at `chezmoi init`
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

Not one hook file is versioned. Four of the five Claude Code hooks are a bare
command on `PATH` - `atuin hook claude-code`, `rtk hook claude`, `gh-axi`,
`chrome-devtools-axi` - with nothing on disk to reproduce. The fifth, herdr,
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

So `run_onchange_after_60-agent-hooks.sh.tmpl` calls each tool's own installer
instead. The declaration did not disappear, it changed form: `packages.yaml` says
which tools exist, the script says how each one installs its hook, and both are
executable rather than a snapshot.

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

`run_onchange_` re-runs when the script's own text changes. Because the package
list is templated into the script body, editing `packages.yaml` changes the text
and re-triggers the run. Nothing hashes anything explicitly.

## Skill restore

The lock file `~/.agents/.skill-lock.json` is written by an agent-side skill, not
by a package manager, so restore is ours to write. Three details decide the shape
of the script:

1. **The lock file's keys are display names.** `"Agent Development"` maps to the
   directory `agent-development`. The directory name comes from
   `basename(dirname(skillPath))`, never from the key. Using the key would produce
   `~/.agents/skills/Agent Development`.
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
not name the cause. It is an SSH remote, so the failure message says so.

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
  minutes; the rendered Brewfile is asserted directly instead.

The apply job also asserts the `~/.claude` file count, which is the standing guard
against the 1.5 GB accident.
