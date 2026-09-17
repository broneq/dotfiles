---
description: Syncing ~/.claude/settings.json back into the repo after Claude Code rewrites it
paths:
  - "home/**/dot_claude/**"
  - "home/**/settings.json*"
---

# `~/.claude/settings.json` sync

Claude Code rewrites this file whenever settings change through the UI, and it
contains two `$HOME`-relative absolute paths, so it must be a chezmoi **template**
with exactly two substitutions: the `bdk` marketplace path and the hook path, both
via `{{ .chezmoi.homeDir }}`.

That combination - application-written *and* templated - means `chezmoi re-add`
will happily overwrite the template with the rendered output. The accepted
workflow after changing settings through the UI is:

```sh
chezmoi re-add --force ~/.claude/settings.json
git diff            # re-check that the two templated paths survived
```

The `git diff` step is the whole point. If the two `{{ .chezmoi.homeDir }}`
occurrences came back as a literal home path, restore them by hand before
committing. `scripts/check.sh` catches the literal path, but only after the fact.

**Do not build automation around this.** Two commands are cheaper than a sync
layer, and the manual diff is what keeps the templating honest.
