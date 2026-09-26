---
name: update-dotfiles
description: Sync this machine's configuration back into the dotfiles repository. Detects every way the live machine drifted from the repo (chezmoi-managed files, merge-script keys, live/ symlinks, packages installed outside packages.yaml), lists the findings in a numbered table, and after approval updates the repository source for the approved numbers. Use on /update-dotfiles, "what changed on my machine", "sync my config into the repo", "update dotfiles from this machine".
---

# update-dotfiles

Direction is **machine to repository**. `chezmoi apply` goes the other way and is
never run here except on one target the user asked to restore.

## 1. Collect

Run the collector from the repository root:

```sh
bash .claude/skills/update-dotfiles/scripts/drift.sh
```

It is read-only and prints one finding per line, tab-separated:
`kind`, `item`, `detail`. Exit 0 with `no drift` on stderr means the machine and
the repository agree; report that and stop. Exit 2 means chezmoi is missing;
stop with that message.

Findings the user rejected earlier on this machine are not printed. They live in
`~/.config/dotfiles.update`, one collector line each (`kind`, `item`, `detail`,
tab-separated; `#` comments and blank lines allowed), and the collector reports
how many it skipped on stderr. Mention that count under the table. The file
belongs to the machine, not to the repository: the two profiles reject
different things, and chezmoi never manages it.

Kinds:

| kind | meaning | where the detail comes from |
|---|---|---|
| `chezmoi` | a managed file, template or symlink whose destination differs from the source | `chezmoi diff --reverse ~/<item>`; `+` lines are what the machine has |
| `modify` | a key owned by a `modify_` merge script differs, or the machine holds an entry under an owned object key that the script does not declare | inline, already semantic (JSON compared sorted) |
| `live` | an uncommitted edit under `live/` | `git diff -- <item>`; the symlink already put it in the tree |
| `brew formula`, `brew cask`, `npm`, `uv` | `+` installed and not declared in `packages.yaml`, `-` declared and not installed | the channel's own list |

For each `chezmoi` line, fetch the reverse diff before building the table. Skim
it for the sake of the "On the machine" column; do not paste whole diffs there.

**Done when:** every collector line has a one-line description of what the
machine changed.

## 2. Summarise

Print one numbered table, every finding on its own row, numbers stable for the
rest of the conversation:

```
| # | Kind | Item | On the machine | In the repository | Proposed action |
```

Proposed action by kind:

| kind | proposed action |
|---|---|
| `chezmoi` file (source has no `.tmpl`, no `modify_`) | `chezmoi re-add ~/<item>` |
| `chezmoi` template | edit the source template by hand; keep the profile branches |
| `chezmoi` template, `.zshrc` | as above, **or** move the line to `~/.zshrc.local` when it belongs to this machine only; the row names both |
| `chezmoi` symlink | the link was replaced by a real file; merge its content into `live/` by hand, then `chezmoi apply ~/<item>` restores the link |
| `modify`, owned key changed | edit the value in the merge script (`jq` object or `awk` line) |
| `modify`, `enabledPlugins.<x>` not declared | add the plugin to the `jq` object **and** its marketplace to `extraKnownMarketplaces` (`claude-plugins-official` excepted); see `.claude/rules/claude-config-sync.md` |
| `modify`, any other extra | ask; it may be Claude Code's own runtime state |
| `live` | nothing to copy; commit it |
| package `+` | add to the matching list in `home/.chezmoidata/packages.yaml`, with a comment when the reason is not obvious from the name; a cask goes under `app_bundle` when it installs an `.app`, else `user_level` |
| package `-` | ask: remove the declaration, or `chezmoi apply` to install it here |

A `+` that is plainly a dependency someone `brew install`ed by hand (`libtiff`,
`librsvg`) still gets a row. Whether it is a tool is the user's call, not the
collector's.

Then ask two things: which numbers to apply (all, a list, or none), and which
of the rest to ignore from now on. Only these rows can be ignored:

- a package row, `+` or `-`
- a `modify` row ending in `present on machine, not declared`

Every other row carries content that keeps changing under the same line, so an
ignore entry would hide later edits too. A row neither applied nor ignored
comes back on the next run. Do not apply or ignore anything before an explicit
answer.

**Done when:** the user named the rows to apply and the rows to ignore.

## 3. Apply

Apply exactly the approved rows, in table order.

Rules that hold for every row:

- Never `chezmoi add` or `chezmoi re-add` a `modify_` target
  (`settings.json`, `profiles.json`, `serena_config.yml`). The merge script is
  the source; a snapshot replaces it.
- Never touch `~/.claude/hooks`, `autoMode`, `~/.config/gh*`, `~/.claude/RTK.md`
  or anything under `~/.claude` that is not already managed. These are the
  tools' own output; `CLAUDE.md` in the repository root says why.
- Package names go into `packages.yaml` only. No script gains a package name.
- An ignored row is appended to `~/.config/dotfiles.update` as the collector
  line, verbatim, under a `# <date>` comment, with `printf '%s\t%s\t%s\n'`.
  Create the file when absent. Never edit or reorder existing lines.
- An ignored row that is a real tool ("installed on purpose, not for the
  repository") is also a scope decision; offer one line in the
  `docs/ROADMAP.md` decisions log. An ignored stray dependency needs nothing
  more.

After a template edit, `chezmoi diff ~/<item>` must be empty. After a merge
script edit, re-run the collector: the row must be gone.

**Done when:** every approved row is applied and its check passed.

## 4. Verify and hand over

```sh
./scripts/check.sh
bash .claude/skills/update-dotfiles/scripts/drift.sh
```

The collector must list only the rows the user declined without ignoring, and
its stderr count must include the rows ignored in this run. When
`packages.yaml` changed, note that the next `chezmoi apply` re-runs the
matching install script (`run_onchange_`), which is a no-op for a package that
is already installed.

Show `git status --short` and propose a Conventional Commits message. Commit
only when asked.
