# dotfiles

The set of tools I work with and the configuration files I author for them,
reproduced across two Macs. Managed by [chezmoi](https://www.chezmoi.io/).

This is a toolbox, not a machine provisioner. It installs packages and writes
configuration. It does not touch macOS system defaults, accounts, login items or
anything requiring MDM cooperation. It contains no secrets.

See `CLAUDE.md` for the contract, `docs/ROADMAP.md` for state, and
`docs/IMPLEMENTATION.md` for how the source tree is put together.

## Bootstrapping a machine

One manual step, because chezmoi cannot install itself from inside a chezmoi run:

```sh
brew install chezmoi
git clone <this repo> ~/projects/dotfiles
chezmoi init --source ~/projects/dotfiles
```

`chezmoi init` asks once for the machine profile and stores the answer in
`~/.config/chezmoi/chezmoi.toml`. Then:

```sh
chezmoi diff          # review every byte that would change on disk
chezmoi apply
```

`chezmoi` is also declared in `packages.yaml`, so the second machine converges on
the same version rather than whatever the bootstrap happened to install.

### The two profiles

The profile describes **privilege level**, not employer.

| Profile | Admin rights | GUI casks install to |
|---|---|---|
| `managed` | no (`staff` only), MDM-enrolled | `~/Applications` |
| `owned` | yes | `/Applications` |

The profile is never derived from the hostname. Machines get renamed; a silently
switched profile is a failure mode you discover a week later.
`run_once_before_00-assert-profile.sh` refuses to continue if `owned` is declared
on an account without admin group membership.

## What is not automated

Four things are deliberately manual. Each one is a decision, not an omission.

1. **Installing chezmoi and Homebrew.** See above.
2. **The GitHub repository.** CI lives in `.github/workflows/test.yml` and runs
   once the repository has a remote. Creating it is not this repo's job.
3. **Replacing a manually installed WezTerm.** `~/Applications/WezTerm.app` exists
   on the `managed` machine with no Homebrew receipt, so `brew bundle` refuses to
   install the cask over it. Move the existing bundle to the trash once, then
   apply. `--force` is not an option here - it is banned repository-wide because
   of what it does to MDM-deployed software.
4. **Two agent skills.** `create-tasks-workspace` and `no-mistakes` are present in
   `~/.agents/skills` but have no entry in `.skill-lock.json`, so there is no
   source to restore them from. The other thirteen restore automatically.

## Verification

```sh
./scripts/check.sh            # always; the mechanical rules
chezmoi diff
chezmoi apply --dry-run -v
```

CI runs `scripts/check.sh`, shellchecks the rendered script templates, and applies
the whole tree into a throwaway `HOME` under both profiles.
