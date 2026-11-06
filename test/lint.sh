#!/usr/bin/env sh
# Static checks on the plugin.  They catch the failures that show up as a
# silently dead plugin instead of a clear error: an unbalanced brace (Kakoune
# counts braces even inside quotes, so one stray `{` breaks the whole module),
# a shell syntax error in any embedded %sh block, an option name that is used
# but never declared, and a command the README promises but the plugin lacks.
set -eu
cd "$(dirname "$0")/.." # repo root
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/color.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/assert.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/extract.sh

plugin=pickers.kak
readme=README.md

[ -f "$plugin" ] || {
  printf '%s\n' "$(cm_red "missing $plugin")"
  exit 1
}

# ---------------------------------------------------------------- braces

opens=$(tr -cd '{' <"$plugin" | wc -c)
closes=$(tr -cd '}' <"$plugin" | wc -c)
if [ "$opens" -ne "$closes" ]; then
  t_fail "braces balance in $plugin" "  $opens { against $closes }"
else
  t_ok "braces balance in $plugin"
fi

# ---------------------------------------------------------------- shell blocks

blocks=$(mktemp -d "${TMPDIR:-/tmp}/pklint.XXXXXX") || exit 1
trap 'rm -rf "$blocks"' EXIT HUP INT TERM
count=$(extract_all_sh_blocks "$plugin" "$blocks") || {
  t_fail 'every %sh block is complete'
  exit 1
}
expected=$(grep -oE '(^|[^%])%sh\{' "$plugin" | wc -l | tr -d ' ')
if [ "${count:-0}" -ne "${expected:-0}" ]; then
  t_fail 'extracted every %sh block' "  extracted ${count:-0} of ${expected:-0}"
  exit 1
fi
t_ok "extracted $count %sh blocks"
bad=
for f in "$blocks"/block.*; do
  dash -n "$f" 2>/dev/null || bad="$bad ${f##*/}"
done
if [ -n "$bad" ]; then
  t_fail 'every %sh block parses under dash' "  failing:$bad"
  for f in "$blocks"/block.*; do
    # shellcheck disable=SC2086  # word splitting is intended
    case " $bad " in *" ${f##*/} "*) printf '\n-- %s\n' "$f"; cat "$f" ;; esac
  done
else
  t_ok 'every %sh block parses under dash'
fi

# ---------------------------------------------------------------- docstrings

# join continuation lines so a command spread over several lines is one line
joined=$(awk '{ while ($0 ~ /\\$/) { sub(/\\$/, ""); if ((getline nxt) <= 0) break; $0 = $0 " " nxt } print }' "$plugin")
missing=$(printf '%s\n' "$joined" | grep 'define-command' | grep -v -- '-hidden' | grep -v -- '-docstring') || missing=
if [ -n "$missing" ]; then
  t_fail 'every public command has a -docstring' "$missing"
else
  t_ok 'every public command has a -docstring'
fi

# ---------------------------------------------------------------- options

declared=$({ grep -oE 'declare-option .*' "$plugin" | grep -oE '_pickers_[a-z_]+' | sort -u; } || true)
used=$(
  {
    grep -oE '%opt\{_pickers_[a-z_]+\}' "$plugin" | sed -E 's/^%opt\{//; s/\}$//'
    grep -oE 'kak_(quoted_)?opt__pickers_[a-z_]+' "$plugin" | sed -E 's/^kak_(quoted_)?opt_//'
    printf '%s\n' "$joined" | grep -E 'set-option' | grep -oE '_pickers_[a-z_]+'
  } | sort -u || true
)
printf '%s\n' "$declared" >"$blocks/declared"
printf '%s\n' "$used" >"$blocks/used"
undeclared=$(comm -13 "$blocks/declared" "$blocks/used")
if [ -n "$undeclared" ]; then
  t_fail 'every option reference is declared' "$undeclared"
else
  t_ok 'every option reference is declared'
fi

# ---------------------------------------------------------------- readme

referenced=$(grep -oE ':pickers-[a-z-]+' "$readme" | sed -E 's/^://' | sort -u || true)
defined=$(printf '%s\n' "$joined" | grep -E '^[[:space:]]*define-command' |
  grep -oE '\bpickers-[a-z-]+' | sort -u)
printf '%s\n' "$referenced" >"$blocks/referenced"
printf '%s\n' "$defined" >"$blocks/defined"
absent=$(comm -13 "$blocks/defined" "$blocks/referenced")
if [ -n "$absent" ]; then
  t_fail 'every command the README maps exists' "$absent"
else
  t_ok 'every command the README maps exists'
fi

# ---------------------------------------------------------------- shellcheck

if ! command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' "$(cm_yellow 'skip shellcheck not installed')"
elif ! (cd test && find . -name '*.sh' -exec shellcheck -s dash {} +); then
  t_fail 'shellcheck is clean'
else
  t_ok 'shellcheck is clean'
fi

t_summary lint
