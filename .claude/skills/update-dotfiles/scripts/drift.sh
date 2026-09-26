#!/usr/bin/env bash
#
# Report every way this machine has drifted from the repository. Read-only.
#
# Prints one line per finding, tab-separated: kind, item, detail. The
# update-dotfiles skill turns those lines into a numbered table and applies the
# approved ones; nothing here writes to the repository or the machine.
# Exit 0 when nothing drifted, 1 when at least one line was printed.
#
# Portability: bash 3.2, so no mapfile and no associative arrays.

set -euo pipefail

# Four sources of drift, one section each:
#
#   chezmoi   managed files and templates whose destination no longer matches
#             the source (`chezmoi status`, scripts excluded)
#   modify    the keys a modify_ script owns, compared semantically: the raw
#             `chezmoi diff` of settings.json is all key order, because Claude
#             Code rewrites the file unsorted, so the comparison sorts both sides
#   live      uncommitted edits under live/, which the symlinks already put in
#             the tree - nothing to copy, only to review and commit
#   packages  each install channel against packages.yaml, in both directions

repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Findings the user rejected on this machine are listed, one collector line
# each, in $DOTFILES_UPDATE_IGNORE (default ~/.config/dotfiles.update) and are
# not printed again. Only findings whose line identifies the drift completely
# can be ignored: a package, or an undeclared settings.json entry. A changed
# file or owned key never can - its line stays the same while the content keeps
# changing, so an ignore entry would hide every later edit.
ignore="${DOTFILES_UPDATE_IGNORE:-$HOME/.config/dotfiles.update}"

found=0

emit() {
	printf '%s\t%s\t%s\n' "$1" "$2" "$3"
	found=1
}

# emit, unless the exact line is in the ignore file. Callers may run in a
# pipeline subshell, so the count goes to a file rather than a variable.
emit_ignorable() {
	line="$(printf '%s\t%s\t%s' "$1" "$2" "$3")"
	if [ -f "$ignore" ] && grep -Fxq -- "$line" "$ignore"; then
		printf '%s\n' "$line" >>"$tmp/ignored"
		return 0
	fi
	emit "$1" "$2" "$3"
}

need() {
	command -v "$1" >/dev/null 2>&1
}

if ! need chezmoi; then
	printf 'chezmoi is not installed; nothing to compare against.\n' >&2
	exit 2
fi

# --- chezmoi: managed targets --------------------------------------------------
# `chezmoi status` prints two columns like git: the second is the difference
# between the destination and the target state, which is the one that matters.
# Scripts are listed with R and are never drift. modify_ targets are excluded
# here and handled semantically below.
chezmoi status 2>/dev/null >"$tmp/status" || true
while IFS= read -r line; do
	[ -n "$line" ] || continue
	code="${line:0:2}"
	target="${line:3}"
	case "$target" in .chezmoiscripts/*) continue ;; esac
	[ "${code:1:1}" != " " ] || continue
	src="$(chezmoi source-path "$HOME/$target" 2>/dev/null || true)"
	base="$(basename "$src")"
	case "$base" in
	modify_*) continue ;;
	symlink_*) kind="symlink" ;;
	*.tmpl) kind="template" ;;
	*) kind="file" ;;
	esac
	emit "chezmoi" "$target" "$code $kind ${src#"$repo"/}"
done <"$tmp/status"

# --- modify: the keys a merge script owns ------------------------------------
# `chezmoi cat` runs the modify_ script against the live file, which is what an
# apply would write. If that differs from the live file, an owned key was changed
# on the machine. JSON is compared sorted; YAML as is.
#
# For settings.json a second question matters: entries the machine has under an
# owned object key (a plugin enabled through the UI, a marketplace it pulled in)
# that the declaration does not list. jq's `*` keeps them, so the first check
# never sees them. The declaration alone is the script run against `{}`.
# profiles.json is not asked that question: a profile added on one machine is
# meant to stay there (see .claude/rules and docs/IMPLEMENTATION.md).
chezmoi managed --include=files --path-style=source-relative 2>/dev/null >"$tmp/managed" || true
while IFS= read -r src_rel; do
	base="$(basename "$src_rel")"
	case "$base" in modify_*) ;; *) continue ;; esac
	target="$(chezmoi target-path "$repo/home/$src_rel" 2>/dev/null || true)"
	[ -n "$target" ] || continue
	rel="${target#"$HOME"/}"
	[ -f "$target" ] || { emit "modify" "$rel" "absent on this machine"; continue; }
	chezmoi cat "$target" >"$tmp/rendered" 2>/dev/null || { emit "modify" "$rel" "chezmoi cat failed"; continue; }
	case "$base" in
	*.json*)
		need jq || { emit "modify" "$rel" "jq missing, not compared"; continue; }
		jq -S . "$target" >"$tmp/live.json"
		jq -S . "$tmp/rendered" >"$tmp/want.json"
		if ! diff -u "$tmp/live.json" "$tmp/want.json" >"$tmp/d" 2>&1; then
			emit "modify" "$rel" "owned key changed on machine (live vs declared):"
			sed 's/^/\t\t/' "$tmp/d" | tail -n +3
		fi
		case "$rel" in
		.claude/settings.json)
			chezmoi execute-template <"$repo/home/$src_rel" >"$tmp/merge.sh"
			printf '{}' | sh "$tmp/merge.sh" | jq -S . >"$tmp/decl.json"
			jq -r --slurpfile d "$tmp/decl.json" '
				$d[0] as $decl
				| [ $decl | to_entries[] | select(.value | type == "object") | .key ] as $objkeys
				| .
				| to_entries[]
				| select(.key as $k | $objkeys | index($k))
				| .key as $k
				| (.value | keys) - ($decl[$k] | keys)
				| .[]
				| "\($k).\(.)"
			' "$target" >"$tmp/extras"
			while IFS= read -r extra; do
				[ -n "$extra" ] || continue
				emit_ignorable "modify" "$rel" "$extra present on machine, not declared"
			done <"$tmp/extras"
			;;
		esac
		;;
	*)
		if ! diff -u "$target" "$tmp/rendered" >"$tmp/d" 2>&1; then
			emit "modify" "$rel" "owned key changed on machine (live vs declared):"
			sed 's/^/\t\t/' "$tmp/d" | tail -n +3
		fi
		;;
	esac
done <"$tmp/managed"

# --- live: symlinked directories -------------------------------------------
# The applications write straight into the tree, so drift here is an uncommitted
# change, not a copy waiting to happen.
git status --short -- live/ >"$tmp/live" 2>/dev/null || true
while IFS= read -r line; do
	[ -n "$line" ] || continue
	emit "live" "${line:3}" "${line:0:2} uncommitted"
done <"$tmp/live"

# --- packages: each channel against packages.yaml ---------------------------
# Declared lists come from chezmoi's own parse of .chezmoidata, so this reads the
# same data the install scripts render. `+` is installed and not declared, `-`
# is declared and not installed.
declared() {
	chezmoi data --format json 2>/dev/null | jq -r "$1 // [] | .[]" | sort -u
}

compare() {
	# $1 kind, $2 declared file, $3 installed file (both sorted, unique)
	comm -13 "$2" "$3" | while IFS= read -r p; do
		[ -n "$p" ] || continue
		emit_ignorable "$1" "$p" "+ installed, not declared"
	done
	comm -23 "$2" "$3" | while IFS= read -r p; do
		[ -n "$p" ] || continue
		emit_ignorable "$1" "$p" "- declared, not installed"
	done
}

# `emit` inside the `while` pipelines above runs in a subshell, so `found` does
# not propagate; count the lines instead.
compare_counted() {
	compare "$@" >"$tmp/cmp"
	if [ -s "$tmp/cmp" ]; then
		cat "$tmp/cmp"
		found=1
	fi
}

if need brew; then
	# `--installed-on-request` is the set a human asked for, dependencies
	# excluded, which is the meaning of the formulae list. `brew leaves` would
	# hide `shellcheck` behind `actionlint`; see packages.yaml.
	declared '.packages.homebrew.formulae + .packages.homebrew.profile_formulae[.profile]' >"$tmp/want"
	brew list --formula --installed-on-request 2>/dev/null | sort -u >"$tmp/have"
	compare_counted "brew formula" "$tmp/want" "$tmp/have"

	declared '.packages.homebrew.casks | to_entries | map(.value) | add' >"$tmp/want"
	brew list --cask 2>/dev/null | sort -u >"$tmp/have"
	compare_counted "brew cask" "$tmp/want" "$tmp/have"
fi

# npm globals live under the nvm-managed node, which is not on PATH in a
# non-interactive shell. Same sourcing as 30-npm-global.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
nvm_sh=""
if need brew; then
	nvm_sh="$(brew --prefix)/opt/nvm/nvm.sh"
fi
if [ -n "$nvm_sh" ] && [ -s "$nvm_sh" ]; then
	# shellcheck disable=SC1090  # path is resolved at runtime, not knowable statically
	. "$nvm_sh"
	nvm use --silent default >/dev/null 2>&1 || true
	declared '.packages.npm' >"$tmp/want"
	# npm and corepack ship with node itself and are never declared.
	npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 |
		xargs -n1 basename 2>/dev/null | grep -vx -e npm -e corepack | sort -u >"$tmp/have" || true
	compare_counted "npm" "$tmp/want" "$tmp/have"
fi

if need uv; then
	declared '.packages.uv' >"$tmp/want"
	# `uv tool list` prints the tool on its own line and its executables
	# indented with `- ` below it.
	uv tool list 2>/dev/null | grep -v '^-' | awk '{ print $1 }' | sort -u >"$tmp/have" || true
	compare_counted "uv" "$tmp/want" "$tmp/have"
fi

# --- verdict -------------------------------------------------------------------
if [ -s "$tmp/ignored" ]; then
	printf '%s ignored as rejected, listed in %s\n' "$(wc -l <"$tmp/ignored" | tr -d ' ')" "$ignore" >&2
fi
if [ "$found" -eq 0 ]; then
	printf 'no drift\n' >&2
	exit 0
fi
exit 1
