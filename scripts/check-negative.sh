#!/usr/bin/env bash
#
# Prove that the gates reject what they claim to reject.
# Exit 0 = every planted violation was caught.

set -euo pipefail

# check.sh and check-templates.sh exiting 0 on a clean tree says nothing on its
# own: a gate with every check accidentally disabled passes just as cleanly. This
# script plants one violation at a time into a throwaway copy of the repository
# and asserts that the right gate fails with the right message.
#
# Asserting the message, not just the exit status, is the point. Exit 1 can come
# from any of the six checks, so a mutation that trips the wrong one would still
# look like a pass.
#
# The two template mutations close phase 6's remaining criterion: "a deliberately
# broken template turns it red".
#
# Portability: macOS ships bash 3.2, so no mapfile and no associative arrays.

cd "$(dirname "$0")/.."
repo="$PWD"

failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sandbox_seq=0
sb=""

fail() {
	printf '\033[31mFAIL\033[0m %s\n' "$1" >&2
	failures=$((failures + 1))
}

pass() {
	printf '\033[32m ok \033[0m %s\n' "$1"
}

# A fresh sandbox per mutation. Cloning is cheap here and leaves no way for one
# case to contaminate the next.
#
# The clone carries the committed tree; the tracked working-tree files are then
# copied over it, so that uncommitted edits to the gates are what gets tested.
new_sandbox() {
	sandbox_seq=$((sandbox_seq + 1))
	sb="$tmp/sb$sandbox_seq"
	git clone --quiet --no-hardlinks "$repo" "$sb"
	git -C "$repo" ls-files | while IFS= read -r f; do
		mkdir -p "$sb/$(dirname "$f")"
		cp "$f" "$sb/$f"
	done
	git -C "$sb" add -A >/dev/null 2>&1
}

# plant <path>, content on stdin
plant() {
	mkdir -p "$sb/$(dirname "$1")"
	cat >"$sb/$1"
	chmod +x "$sb/$1" 2>/dev/null || true
	git -C "$sb" add -f "$1" >/dev/null 2>&1
}

# expect_rejected <gate> <needle> <description>
expect_rejected() {
	gate="$1"
	needle="$2"
	desc="$3"
	log="$tmp/log$sandbox_seq"

	if (cd "$sb" && "./scripts/$gate") >"$log" 2>&1; then
		fail "$desc: $gate exited 0, the violation was not caught"
		return 0
	fi
	if ! grep -qF "$needle" "$log"; then
		fail "$desc: $gate failed, but not with \"$needle\""
		sed 's/^/       /' "$log" >&2
		return 0
	fi
	pass "$desc"
}

# expect_clean <gate> <description>
expect_clean() {
	gate="$1"
	desc="$2"
	log="$tmp/log$sandbox_seq-clean"

	if (cd "$sb" && "./scripts/$gate") >"$log" 2>&1; then
		pass "$desc"
	else
		fail "$desc: $gate rejected an unmodified tree"
		sed 's/^/       /' "$log" >&2
	fi
}

# --- control: an unmodified copy must pass both gates -------------------------
# Without this, every assertion below could be satisfied by a gate that rejects
# everything.
new_sandbox
expect_clean check.sh "control: clean tree passes check.sh"
expect_clean check-templates.sh "control: clean tree passes check-templates.sh"

# --- 1. sudo ------------------------------------------------------------------
new_sandbox
plant scripts/planted-probe.sh <<'PLANT'
#!/usr/bin/env bash
set -euo pipefail
sudo ls /
PLANT
expect_rejected check.sh "sudo call in a script" "sudo is rejected"

# --- 2. destructive brew bundle ----------------------------------------------
new_sandbox
plant scripts/planted-probe.sh <<'PLANT'
#!/usr/bin/env bash
set -euo pipefail
brew bundle install --cleanup --file=/dev/null
PLANT
expect_rejected check.sh "brew bundle --cleanup/--force" "brew bundle --cleanup is rejected"

# --- 3. hardcoded absolute home path -----------------------------------------
# Planted into Markdown: prose is scanned too, and it keeps the shell checks out
# of the way so only the path check can fire.
new_sandbox
plant docs/planted-probe.md <<'PLANT'
Scratch file. The path below is what this case exists to trip.

    /Users/somebody/projects/dotfiles
PLANT
expect_rejected check.sh "hardcoded absolute home path" "hardcoded home path is rejected"

# --- 4. missing prologue ------------------------------------------------------
new_sandbox
plant scripts/planted-probe.sh <<'PLANT'
#!/usr/bin/env bash
echo "no prologue here"
PLANT
expect_rejected check.sh "missing 'set -euo pipefail'" "missing prologue is rejected"

# --- 5. secret ----------------------------------------------------------------
# Assembled at runtime so that this file does not itself carry a string in the
# shape the tripwire looks for.
new_sandbox
{
	printf 'Scratch file.\n\n    token: gh'
	printf 'p_%s\n' "AbCdEfGhIjKlMnOpQrStUvWx"
} | plant docs/planted-probe.md
expect_rejected check.sh "possible secret committed" "secret-shaped string is rejected"

# --- 6. shellcheck ------------------------------------------------------------
# Prologue present and no other rule tripped, so only shellcheck can fail. The
# violation is a parse error rather than a style nit, which keeps the case
# independent of shellcheck's default severity.
new_sandbox
plant scripts/planted-probe.sh <<'PLANT'
#!/usr/bin/env bash
set -euo pipefail
if [ -z "${1:-}" ; then
	echo "unreachable"
fi
PLANT
expect_rejected check.sh "shellcheck reported problems" "shellcheck violation is rejected"

# --- 7. template that renders into broken shell -------------------------------
new_sandbox
plant home/.chezmoiscripts/run_onchange_97-broken-shell.sh.tmpl <<'PLANT'
#!/usr/bin/env bash
set -euo pipefail
{{ if eq .profile "managed" -}}
if [ -z "${HOME:-}" ; then
	echo "unreachable"
fi
{{ end -}}
PLANT
expect_rejected check-templates.sh "97-broken-shell.sh: shellcheck" \
	"template rendering into broken shell is rejected"

# --- 8. template that does not render ----------------------------------------
new_sandbox
plant home/.chezmoiscripts/run_onchange_98-broken-template.sh.tmpl <<'PLANT'
#!/usr/bin/env bash
set -euo pipefail
echo {{ .no.such.key }}
PLANT
expect_rejected check-templates.sh "98-broken-template.sh: render failed" \
	"template that does not render is rejected"

# --- verdict ------------------------------------------------------------------
echo
if [ "$failures" -gt 0 ]; then
	printf '\033[31m%d negative check(s) failed.\033[0m\n' "$failures" >&2
	exit 1
fi
printf '\033[32mEvery planted violation was caught.\033[0m\n'
