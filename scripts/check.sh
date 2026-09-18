#!/usr/bin/env bash
#
# Mechanical guardrails for this repository.
#
# Every check here replaces a rule that used to live in CLAUDE.md as prose and
# therefore depended on an agent remembering it. Run locally before proposing a
# change; CI runs the same script.
#
# Portability: macOS ships bash 3.2, so no mapfile, no associative arrays, and no
# `${arr[@]}` under `set -u` on a possibly-empty array. Keep it that way - this
# script must run on a machine where nothing has been installed yet.
#
# Exit 0 = clean. Exit 1 = at least one violation, each printed with its location.

set -euo pipefail

cd "$(dirname "$0")/.."

failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
	printf '\033[31mFAIL\033[0m %s\n' "$1" >&2
	failures=$((failures + 1))
}

pass() {
	printf '\033[32m ok \033[0m %s\n' "$1"
}

# git grep searches tracked files by default, which is what we want: untracked
# scratch files are not the repository's problem, and the behaviour is identical
# locally and in CI.
#
# Two files are excluded from the content checks because both have to contain the
# very patterns they search for: this script, and check-negative.sh, which plants
# each violation in turn to prove these checks still fire.
grep_tracked() {
	git grep -n -E "$1" -- . \
		':(exclude)scripts/check.sh' \
		':(exclude)scripts/check-negative.sh' >"$tmp/hits" 2>/dev/null
}

report() {
	fail "$1"
	sed 's/^/       /' "$tmp/hits" >&2
}

# Plain shell scripts, and chezmoi script templates, as newline-separated lists.
git ls-files -- '*.sh' '*.bash' >"$tmp/shell" || true
git ls-files -- '*.sh.tmpl' '*.bash.tmpl' >"$tmp/templates" || true
shell_count=$(wc -l <"$tmp/shell" | tr -d ' ')
template_count=$(wc -l <"$tmp/templates" | tr -d ' ')

# --- 1. No hardcoded absolute home paths -------------------------------------
# Two usernames exist across the two machines. `$HOME` in shell,
# `{{ .chezmoi.homeDir }}` in templates. Anything else is a bug.
if grep_tracked '/Users/[A-Za-z0-9._-]+'; then
	report "hardcoded absolute home path (use \$HOME or {{ .chezmoi.homeDir }}):"
else
	pass "no hardcoded absolute home paths"
fi

# --- 2. No sudo in scripts ----------------------------------------------------
# On `managed` there are no admin rights, so sudo hangs on a password prompt the
# user cannot satisfy. Detect the condition and fail loudly instead.
if git grep -n -E '(^|[^[:alnum:]_-])sudo[[:space:]]' -- \
	'*.sh' '*.bash' '*.sh.tmpl' '*.bash.tmpl' \
	':(exclude)scripts/check.sh' ':(exclude)scripts/check-negative.sh' \
	>"$tmp/hits" 2>/dev/null; then
	report "sudo call in a script (managed machines have no admin rights):"
else
	pass "no sudo calls in scripts"
fi

# --- 3. No destructive brew bundle -------------------------------------------
# MDM pushes software that the script cannot distinguish from user-installed
# leftovers, so convergence-with-removal is never safe to write unconditionally.
#
# Scoped to executable files: prose in *.md documents the rule and must be able to
# name the flags it forbids.
if git grep -n -E 'brew[[:space:]]+bundle.*(--cleanup|--force)' -- \
	'*.sh' '*.bash' '*.sh.tmpl' '*.bash.tmpl' 'Brewfile*' \
	':(exclude)scripts/check.sh' ':(exclude)scripts/check-negative.sh' \
	>"$tmp/hits" 2>/dev/null; then
	report "brew bundle --cleanup/--force (removes MDM-deployed software):"
else
	pass "no destructive brew bundle invocations"
fi

# --- 4. Script prologue -------------------------------------------------------
# Idempotence starts with failing on the first error rather than limping on.
prologue_bad=0
while IFS= read -r f; do
	[ -n "$f" ] || continue
	if ! head -n 15 "$f" | grep -qF 'set -euo pipefail'; then
		fail "$f: missing 'set -euo pipefail' in the first 15 lines"
		prologue_bad=1
	fi
done <"$tmp/shell"
while IFS= read -r f; do
	[ -n "$f" ] || continue
	if ! head -n 15 "$f" | grep -qF 'set -euo pipefail'; then
		fail "$f: missing 'set -euo pipefail' in the first 15 lines"
		prologue_bad=1
	fi
done <"$tmp/templates"
if [ "$prologue_bad" -eq 0 ]; then
	pass "every shell file sets -euo pipefail"
fi

# --- 5. shellcheck ------------------------------------------------------------
# Chezmoi templates are not valid shell until rendered, so they are skipped here.
# scripts/check-templates.sh renders them under both profiles and shellchecks the
# result; it is separate because it needs chezmoi, and this script must run on a
# machine where nothing is installed yet.
if [ "$shell_count" -gt 0 ]; then
	if ! command -v shellcheck >/dev/null 2>&1; then
		fail "shellcheck is not installed - 'brew install shellcheck'"
	elif xargs shellcheck <"$tmp/shell"; then
		pass "shellcheck clean ($shell_count file(s))"
	else
		fail "shellcheck reported problems"
	fi
else
	pass "shellcheck: no plain shell scripts yet"
fi

if [ "$template_count" -gt 0 ]; then
	printf ' \033[33m--\033[0m %s\n' \
		"$template_count script template(s) skipped here; run scripts/check-templates.sh"
fi

# --- 6. Secret scan -----------------------------------------------------------
# The repository holds no secrets by design. This is a tripwire for the obvious
# shapes, not a replacement for that decision.
if grep_tracked 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'; then
	report "possible secret committed:"
else
	pass "no secret-shaped strings"
fi

# --- 7. NVM_DIR before nvm.sh -------------------------------------------------
# Homebrew's nvm.sh shim opens with `[ -z "$NVM_DIR" ] && export NVM_DIR=...`,
# which is an unbound dereference under `set -u` and kills the whole script. An
# interactive shell never reaches it because .zshrc exported the variable long
# before; a fresh CI runner has not, so this fails there and nowhere else. It was
# caught that way once already, after the nvm block was copied from
# 30-npm-global.sh into 60-agent-hooks.sh without the export.
nvm_bad=0
git grep -l -F 'opt/nvm/nvm.sh' -- \
	'*.sh' '*.bash' '*.sh.tmpl' '*.bash.tmpl' \
	':(exclude)scripts/check.sh' ':(exclude)scripts/check-negative.sh' \
	>"$tmp/nvm" 2>/dev/null || true
while IFS= read -r f; do
	[ -n "$f" ] || continue
	# First mention of the path, not the `.` line: both scripts build the path
	# into a variable first, and the export has to precede even that.
	# `|| true` on both: under `set -e` an assignment carries the exit status of
	# its command substitution, and a missing export is the whole point of this
	# check - without the guard it aborts the gate instead of reporting.
	use_line=$(grep -nF 'opt/nvm/nvm.sh' "$f" | head -n 1 | cut -d: -f1 || true)
	exp_line=$(grep -nE 'export[[:space:]]+NVM_DIR=' "$f" | head -n 1 | cut -d: -f1 || true)
	[ -n "$use_line" ] || continue
	if [ -z "$exp_line" ] || [ "$exp_line" -gt "$use_line" ]; then
		fail "$f:$use_line: uses nvm.sh without exporting NVM_DIR first (unbound under set -u)"
		nvm_bad=1
	fi
done <"$tmp/nvm"
if [ "$nvm_bad" -eq 0 ]; then
	pass "every nvm.sh user exports NVM_DIR first"
fi

# --- verdict ------------------------------------------------------------------
echo
if [ "$failures" -gt 0 ]; then
	printf '\033[31m%d check(s) failed.\033[0m\n' "$failures" >&2
	exit 1
fi
printf '\033[32mAll checks passed.\033[0m\n'
