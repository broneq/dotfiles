# CLAUDE.md

Project instructions for agents working in this repository.

This file holds repository facts and the invariants whose violation **fails
silently**. Everything that only matters while touching one path lives in
`.claude/rules/`. Everything mechanically checkable lives in `scripts/check.sh`.
Project state lives in `docs/ROADMAP.md`, and nowhere else. How the source tree is
put together - file roles, template mechanics, the traps each script avoids - lives
in `docs/IMPLEMENTATION.md`, which carries no status of its own.

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
   `cask_args appdir:` in the rendered Brewfile. `brew bundle` has no `--appdir`
   flag; the argument belongs to the Brewfile, not the command line. This is why
   WezTerm works there without admin.
4. Validate the declared profile against reality. If the profile says `owned` but
   `dsmemberutil checkmembership -U "$(id -un)" -G admin` reports no membership,
   abort. A configuration that lies about its environment is worse than none.

Rules 1 and 2 are enforced by `scripts/check.sh`. Rules 3 and 4 are not
mechanically checkable and are on you.

## Hard rules

### Never version a directory that contains runtime state

`~/.claude` and `~/.config/herdr` each hold orders of magnitude more runtime data
than authored files. The surveyed sizes are in `docs/ROADMAP.md`, under
"Runtime state, never versioned".

**Always whitelist individual files.** Never add a whole directory unless you have
verified every path under it is authored.

Exception: `~/.config/nvim` and `~/.config/wezterm` are clean. Neovim keeps plugin
state in `stdpath("data")`, not in the config directory.

### Never hardcode an absolute home path

Two usernames exist across the two machines. Use `$HOME` in shell and
`{{ .chezmoi.homeDir }}` in templates. Enforced by `scripts/check.sh`.

### One source of truth for packages

All package lists live in `home/.chezmoidata/packages.yaml`, keyed by channel and
profile. Scripts consume that file and contain no package names of their own.
Adding a tool is a one-line YAML change, never a shell edit.

A tool the repository depends on must be declared there even when it is already
present on this machine as some other formula's dependency. Transitive presence
disappears the moment the parent does.

### Scripts are idempotent

Every `run_onchange_` and `run_once_` script must survive being run ten times.
Start with `set -euo pipefail`. Guard every source and every install.
Both the prologue and `shellcheck` are enforced by `scripts/check.sh`.

## File handling policy

Two categories, decided by **who writes the file**:

**Symlink into the repo** when the application rewrites the file and you want
those edits to land in git: `~/.config/nvim/`, `~/.config/wezterm/`,
`~/.config/herdr/config.toml`. Real files live under `live/`; chezmoi creates the
symlink, and edits made in either place are the same bytes.

**chezmoi-managed file or template** when only a human writes it: `~/.zshrc`,
`~/.zprofile`, `~/.gitconfig`, `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`.

**Merge, never copy**, when the file has more than one author.
`~/.claude/settings.json` is written by Claude Code, by this repository, and by
five installed tools. It is handled by `modify_settings.json.tmpl`, which merges
the keys this repository owns and leaves every other key alone. Never
`chezmoi add` or `re-add` it. See `.claude/rules/claude-config-sync.md`.

**A tool's own integration is not authored configuration.** Hooks are installed by
the tools that own them (`herdr integration install`, `atuin hook install`,
`rtk init`, `gh-axi setup hooks`, `chrome-devtools-axi setup hooks`), never copied
into the repository. A vendored file in git cannot track the vendor's version, and
`chezmoi apply` would revert the vendor's own upgrade.

## Install channels

Four channels exist because four are genuinely in use. Do not try to collapse them
into one; each owns a distinct class of tool.

| Channel | Owns | Notes |
|---|---|---|
| Homebrew | CLI tools, GUI casks | `Brewfile` generated from `packages.yaml` |
| mise | language runtimes (node, python, go, bun) | replaces nvm |
| npm global | `*-axi` CLI tools | migration to mise is roadmap phase 7 |
| uv tools | `code-review-graph` | `uv` itself is a standalone binary |

Project-scoped dependencies belong to the project, never here.

## Verification

Match the check to what changed.

```sh
./scripts/check.sh            # always; the mechanical rules above
chezmoi diff                  # review every byte that would change on disk
chezmoi apply --dry-run -v
```

CI runs `scripts/check.sh` and a clean `chezmoi apply` on `macos-latest`. A change
that cannot be applied to a fresh machine is not finished.

Documentation-only edits need `scripts/check.sh` and nothing else.

## Conventions

- Documentation language: technical English, imperative mood, explicit instructions
- Commit messages: Conventional Commits
- Repository visibility: **public**. That makes the no-secrets rule above
  load-bearing rather than a precaution: the repository lists the tooling of an
  MDM-managed work machine, names its MDM vendor, and states that the account has
  no admin rights. Anything added here is published. Reversed from `private` on
  2026-09-17 by the repository owner; see the decisions log.
- Record every scope decision in `docs/ROADMAP.md`, including decisions to say no
