#!/usr/bin/env bash
#
# Render every chezmoi script template under both profiles and shellcheck the
# result. Exit 0 = all of them render and are clean.

set -euo pipefail

# Separate from scripts/check.sh on purpose: check.sh must run on a machine where
# nothing is installed yet, so it cannot require chezmoi. This one does, and
# therefore cannot be part of the bootstrap gate.
#
# It lives here rather than inline in the CI workflow so that it can be run by
# hand, which is also what lets scripts/check-negative.sh plant a broken template
# and assert that this script rejects it.
#
# Portability: macOS ships bash 3.2, so no mapfile and no associative arrays.

cd "$(dirname "$0")/.."

# The prompt text is the lookup key for --promptChoice; it is not the name of the
# field the answer lands in. It must stay identical to the string in
# home/.chezmoi.toml.tmpl, and must contain no comma and no `=`, because the flag
# parses comma-separated key=value pairs. Get either wrong and chezmoi prompts,
# finds no TTY, and hands the template the prompt string as the answer.
PROMPT='Machine profile'

if ! command -v chezmoi >/dev/null 2>&1; then
	printf 'chezmoi is not installed - "brew install chezmoi"\n' >&2
	exit 1
fi
if ! command -v shellcheck >/dev/null 2>&1; then
	printf 'shellcheck is not installed - "brew install shellcheck"\n' >&2
	exit 1
fi

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

for profile in managed owned; do
	cfg="$tmp/$profile.toml"

	# --persistent-state keeps this out of ~/.config/chezmoi. Without it, running
	# this script by hand leaves a recorded config-template hash behind, and the
	# next real `chezmoi init` warns that the template changed.
	if ! chezmoi init \
		--source . \
		--promptChoice "$PROMPT=$profile" \
		--destination "$tmp/home-$profile" \
		--config-path "$cfg" \
		--persistent-state "$tmp/$profile-state.boltdb" \
		--no-tty >"$tmp/$profile-init.log" 2>&1; then
		fail "$profile: chezmoi init failed"
		sed 's/^/       /' "$tmp/$profile-init.log" >&2
		continue
	fi

	# `init` answering itself is the failure mode that produced a plausible-looking
	# render for as long as CI existed. Catch it here rather than downstream.
	if ! grep -q "profile = \"$profile\"" "$cfg"; then
		fail "$profile: the prompt was not answered by --promptChoice"
		sed 's/^/       /' "$cfg" >&2
		continue
	fi

	for tmpl in home/.chezmoiscripts/*.sh.tmpl home/dot_claude/modify_settings.json.tmpl; do
		[ -f "$tmpl" ] || continue
		name="$(basename "${tmpl%.tmpl}")"
		out="$tmp/$profile-$name"

		if ! chezmoi execute-template \
			--config "$cfg" \
			--persistent-state "$tmp/$profile-state.boltdb" \
			<"$tmpl" >"$out" 2>"$out.err"; then
			fail "$profile/$name: render failed"
			sed 's/^/       /' "$out.err" >&2
			continue
		fi

		# modify_settings.json.tmpl is POSIX sh; every install script is bash.
		case "$name" in
		modify_*) shell="sh" ;;
		*) shell="bash" ;;
		esac

		if shellcheck --shell="$shell" "$out" >"$out.sc" 2>&1; then
			pass "$profile/$name"
		else
			fail "$profile/$name: shellcheck"
			sed 's/^/       /' "$out.sc" >&2
		fi
	done
done

echo
if [ "$failures" -gt 0 ]; then
	printf '\033[31m%d template check(s) failed.\033[0m\n' "$failures" >&2
	exit 1
fi
printf '\033[32mAll templates render and shellcheck clean.\033[0m\n'
