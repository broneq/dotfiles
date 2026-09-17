# CLAUDE.md

Project instructions for agents working in this repository.

## What this repository is

A **toolbox**, not a machine provisioner. It reproduces the set of tools I work
with and the configuration files I author for them, across two Macs.

Managed by [chezmoi](https://www.chezmoi.io/). Source of truth is this repo;
`chezmoi apply` writes to the live machine.

### In scope

- Package installation across four channels (Homebrew, npm global, uv tools, mise)
- Authored configuration files for: zsh, git, Neovim, WezTerm, herdr, Claude Code
- Claude Code agent layer: `CLAUDE.md`, `settings.json`, hooks, plugins, skills
- Language toolchains: node, python, go, bun
- Container tooling: colima, docker

### Explicitly out of scope

Do not add these without an explicit decision recorded in `docs/ROADMAP.md`:

- macOS system defaults (`defaults write`, Dock, Finder, keyboard)
- Account creation, login items, app sign-in state
- Secrets of any kind: SSH keys, GPG keys, API tokens, credentials
- Anything requiring MDM cooperation or IT tickets

The repository contains **no secrets**. If a change would introduce one, stop and
raise it instead of encrypting it.

## The two profiles

The profile describes **privilege level**, not employer. Never name profiles
"work" and "personal"; the constraint that matters is what the machine lets you do.

| Profile | Machine | Admin rights | MDM | Homebrew prefix |
|---|---|---|---|---|
| `managed` | work Mac | **no** (`staff` only) | Mosyle, DEP-enrolled | `/opt/homebrew`, owned by the user |
| `owned` | personal Mac | yes (root) | none | `/opt/homebrew` |

The profile is chosen once during `chezmoi init` via `promptChoiceOnce` and stored
in `~/.config/chezmoi/chezmoi.toml`.

**Never derive the profile from hostname.** Macs get renamed; a silently switched
profile is a failure mode you discover a week later.

### Privilege rules

1. **Never call `sudo` in any script.** On `managed` it will hang on a password
   prompt the user cannot satisfy. If an operation needs admin, detect the
   condition and fail with an actionable message.
2. **Never run `brew bundle --cleanup` or `--force` on `managed`.** MDM pushes
   software, and the script cannot distinguish "mine, obsolete" from "deployed by
   IT". Convergence-with-removal is allowed on `owned` only, and only once the
   package list is known to be complete.
3. **GUI casks install to `$HOME/Applications` on `managed`** via
   `--appdir="$HOME/Applications"`. This is why WezTerm works there without admin.
4. Validate the declared profile against reality. If the profile says `owned` but
   `dsmemberutil checkmembership -U "$(id -un)" -G admin` reports no membership,
   abort. A configuration that lies about its environment is worse than none.

## Hard rules

### Never version a directory that contains runtime state

`~/.claude` holds roughly 1.5 GB of runtime data (`projects/`, `jobs/`,
`file-history/`, `history.jsonl`, `plugins/cache/`) alongside about eight authored
files. `~/.config/herdr` holds a 5 MB server log next to a 132-byte config.

**Always whitelist individual files.** Never add a whole directory unless you have
verified every path under it is authored.

Exception: `~/.config/nvim` and `~/.config/wezterm` are clean. Neovim keeps plugin
state in `stdpath("data")`, not in the config directory.

### Never hardcode an absolute home path

Two usernames exist across the two machines. Use `$HOME` in shell and
`{{ .chezmoi.homeDir }}` in templates. A literal `/Users/<name>` anywhere in this
repo is a bug.

### One source of truth for packages

All package lists live in `home/.chezmoidata/packages.yaml`, keyed by channel and
profile. Scripts consume that file and contain no package names of their own.
Adding a tool is a one-line YAML change, never a shell edit.

### Scripts are idempotent

Every `run_onchange_` and `run_once_` script must survive being run ten times.
Start with `set -euo pipefail`. Guard every source and every install.
All scripts must pass `shellcheck`.

## File handling policy

Two categories, decided by **who writes the file**:

**Symlink into the repo** when the application rewrites the file and you want
those edits to land in git:

- `~/.config/nvim/` (Neovim and lazy.nvim rewrite `lazy-lock.json`)
- `~/.config/wezterm/`
- `~/.config/herdr/config.toml`

Real files live under `live/` in this repo. chezmoi creates the symlink; edits
made in either place are the same bytes.

**chezmoi-managed file or template** when only a human writes it:

- `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`
- `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`
- `~/.claude/hooks/herdr-agent-state.sh`

**Special case: `~/.claude/settings.json`.** Claude Code rewrites it, and it
contains two `$HOME`-relative absolute paths, so it must be a template. The
accepted workflow after changing settings through the UI is:

```sh
chezmoi re-add --force ~/.claude/settings.json
git diff            # re-check that the two templated paths survived
```

Do not build automation around this. Two commands is cheaper than a sync layer.

## Install channels

Four channels exist because four are genuinely in use. Do not try to collapse them
into one; each owns a distinct class of tool.

| Channel | Owns | Notes |
|---|---|---|
| Homebrew | CLI tools, GUI casks | `Brewfile` generated from `packages.yaml` |
| mise | language runtimes (node, python, go, bun) | replaces nvm |
| npm global | `*-axi` CLI tools | currently pinned under an nvm node version |
| uv tools | `code-review-graph` | `uv` itself is a standalone binary |

Project-scoped dependencies belong to the project, never here.

## Verification

Before proposing a change as done:

```sh
chezmoi diff                  # review every byte that would change on disk
chezmoi apply --dry-run -v
shellcheck home/**/*.sh
```

CI runs a clean `chezmoi apply` on `macos-latest`. A change that cannot be applied
to a fresh machine is not finished.

Do not run the full verification suite after editing documentation only.

## Keeping the roadmap honest

`docs/ROADMAP.md` is the working state of this project, not a proposal written
once. Every change to the repository updates it in the **same commit** as the work.

1. **Tick a checkbox only after its verification passed.** `[x]` means the phase's
   "Done when" criterion was actually run and observed, not that the code was
   written. Use `[~]` for started-but-unverified. A plan that claims more than the
   repository delivers is worse than no plan.
2. **Never mark a phase complete while any of its boxes are open.**
3. **Correct "Current state" when you learn it is wrong.** It is a factual survey
   with real sizes, paths and counts. Stale facts there cause bad decisions three
   phases later. Say plainly in the commit message that a fact was corrected.
4. **Append to the decisions log whenever a choice is made**, including choices to
   say no, and record the rationale, not just the outcome.
5. **Move an item from "Open questions" to the decisions log when it is settled**,
   rather than deleting it. The trail is the point.

Do not add status tracking anywhere else. One file, one truth.

## Conventions

- Documentation language: technical English, imperative mood, explicit instructions
- Commit messages: Conventional Commits, no agent name as co-author
- Repository visibility: **private**. It lists the tooling of an MDM-managed work
  machine. There are no secrets in it, but that is not a reason to publish it.
- Record every scope decision in `docs/ROADMAP.md`, including decisions to say no
