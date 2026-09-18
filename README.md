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

`chezmoi init` asks once for the machine profile:

```
Machine profile (managed/owned)?
```

Answer `managed` on the MDM-enrolled work Mac with no admin rights, `owned` on the
personal Mac with root. The prompt is deliberately terse - it doubles as the lookup
key CI uses to answer it without a terminal, and a key containing a comma or an `=`
cannot be matched. The table below is the long form.

The answer, and the source directory `init` was pointed at, are both stored in
`~/.config/chezmoi/chezmoi.toml`. The second half matters: `chezmoi init --source`
does not persist that path by itself, so without it the `chezmoi apply` below would
resolve to `~/.local/share/chezmoi`, find nothing and report success. Then:

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

Six things are deliberately manual. Each one is a decision, not an omission.

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
5. **Logging the `private` git identity in.** The `git-identity` plugin is
   declared in `settings.json` and its `private` profile is written to
   `~/.config/git-identity/profiles.json`, but the profile points at a `gh` config
   directory that only a browser OAuth flow can fill:

   ```sh
   GH_CONFIG_DIR=~/.config/gh-private gh auth login
   GH_CONFIG_DIR=~/.config/gh-private gh auth setup-git
   ```

   The second command is not optional. macOS sets `credential.helper = osxkeychain`
   in the system git config, which caches whichever token it saw first for
   github.com and hands it to every profile afterwards; `gh auth setup-git` writes a
   per-host entry that resets that list. Skip it and you get a profile that reads
   correctly and pushes as the wrong account.

   `~/.config/gh-private` itself is never versioned - see the decisions log. Bind a
   project to the profile afterwards with `/git-identity:use private`, which writes
   `.claude/settings.local.json`; that file holds absolute paths from one machine's
   home directory and stays out of every repository.
6. **`claude` itself.** A standalone binary in `~/.local/bin` that no install
   channel declares; the whole agent layer is configured for it. Tracked as an
   open question in `docs/ROADMAP.md`, not as a decision.

   `herdr` used to be in the same position and is now the Homebrew formula. A
   machine that still carries the `curl | sh` copy in `~/.local/bin` must delete
   it by hand: that directory precedes `/opt/homebrew/bin` on `PATH`, so the
   standalone binary would shadow the one Homebrew keeps current.

## Verification

Three gates, all runnable by hand. CI runs the same three.

```sh
./scripts/check.sh            # mechanical rules; needs nothing installed
./scripts/check-templates.sh  # renders every template under both profiles, shellchecks it
./scripts/check-negative.sh   # plants each violation in turn, asserts the gates catch it

chezmoi diff
chezmoi apply --dry-run -v
```

`check-negative.sh` exists because the other two passing says nothing on its own:
a gate with every check accidentally disabled passes just as cleanly.

Two workflows:

- **`test.yml`**, on every push and pull request, seconds. The three gates, then an
  apply into a throwaway `HOME` under both profiles, a `settings.json` seeded with
  what the other two authors write, a second apply that must change nothing, the
  skill restore executed for real, and every declared package name checked against
  its registry. It does **not** run the install scripts.
- **`install.yml`**, weekly and on demand, tens of minutes. The fresh-machine test:
  the same apply with the install scripts included, on a runner that really is a
  clean Mac. It is the only thing that executes `brew bundle`, the npm globals, the
  uv bootstrap and the five hook installers.

Documentation-only edits need `scripts/check.sh` and nothing else.
