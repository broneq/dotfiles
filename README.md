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

On `managed` it also asks for the herdr tunnel target; see "What is not
automated", point 7.

The answers, and the source directory `init` was pointed at, are all stored in
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

Seven things are deliberately manual. Each one is a decision, not an omission.

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
7. **Reaching the `owned` machine's herdr from `managed`.** herdr attaches to
   another machine over SSH only, and the SSH connection runs through a
   Cloudflare Tunnel with Cloudflare Access in front of it. Every piece of this is
   either a secret (the tunnel token, the SSH key), a system setting that needs
   admin (Remote Login), or a Cloudflare dashboard object, so none of it is
   versioned. `cloudflared` itself is declared in `packages.yaml`.

   Only this direction is set up. The `managed` machine opens an outbound
   connection and listens on nothing; see the open question in
   `docs/ROADMAP.md` for the reverse direction.

   On the `owned` machine:

   1. System Settings, General, Sharing: turn on **Remote Login**, allowed for
      your user only.
   2. Cloudflare dashboard, Zero Trust, Networks, Tunnels: create a
      `cloudflared` tunnel and add a public hostname, for example
      `ssh.example.com`, with service `ssh://localhost:22`.
   3. Install the connector the dashboard shows. `sudo` here is typed by a human
      on the machine that has admin rights, not run by a script:

      ```sh
      sudo cloudflared service install <tunnel-token>
      ```

   4. Zero Trust, Access, Applications: add a self-hosted application for the
      same hostname, with a policy that allows only your own email. Without it
      the SSH port is on the public internet.

   On the `managed` machine, `chezmoi init` asks once for the tunnel target:

   ```
   Tunnel SSH target for herdr?
   ```

   Answer `<owned-username>@ssh.example.com`, or leave it empty to skip the whole
   connection. A machine initialised before this prompt existed gets it on its
   next `chezmoi init`. The answer stays in `~/.config/chezmoi/chezmoi.toml`,
   never in the repository, and `chezmoi apply` then writes the `owned-mac` alias
   to `~/.ssh/config.d/herdr-remote` and adds `Include config.d/*` to
   `~/.ssh/config` without touching its other entries. On the `owned` machine,
   `chezmoi apply` appends the `managed` public key, declared in
   `home/.chezmoidata/remote.yaml`, to `~/.ssh/authorized_keys` and leaves every
   other key there alone. One step stays manual, on `managed`:

   1. Log in to Cloudflare Access, which opens a browser:

      ```sh
      cloudflared access login https://ssh.example.com
      ```

   The next `chezmoi apply` checks that `ssh owned-mac` logs in and runs
   `herdr machine add --label owned owned-mac`; the machine then appears in the
   herdr sidebar. Until both steps are done, apply prints which one is missing and
   carries on. The `owned` machine must have been applied at least once since the
   key was declared.

   The Access token expires with the application's session duration. When herdr
   stops reaching the machine, repeat the `cloudflared access login` above. Keep
   herdr on the same version on both machines: remote attach needs API-compatible
   servers.

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

The other direction - a tool installed or a setting changed on the machine that the
repository should learn about - is the `/update-dotfiles` skill in Claude Code.
Its collector runs on its own too and prints one line per drift:

```sh
bash .claude/skills/update-dotfiles/scripts/drift.sh
```
