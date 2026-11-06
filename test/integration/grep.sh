#!/usr/bin/env sh
# The grep buffer commands: pickers-grep-open jumps to the match under the
# cursor and pickers-grep-write saves the edited lines back to their files.
#
# The picker buffer is built here instead of through the picker prompt, so the
# tests do not depend on the `fifo` command that the prompt path needs.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # harness sources the shared helpers
. test/integration/harness.sh
pk_require_kak

export LC_ALL=C
work=$(mktemp -d "${TMPDIR:-/tmp}/pktest.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM

# ---------------------------------------------------------------- grep-open

tree=$work/open/tree
pk_mkfixture "$tree"
cd "$tree"
pk_start "$work/open" "$(pk_init "edit -debug -scratch '*pickers-grep*'
execute-keys 'ia.txt:2:beta two<ret>b.txt:1:delta four<esc>'
write -force '$work/open/src'
execute-keys '1G'
pickers-grep-open
pk-test-state '$work/open/state'")"
pk_wait "$work/open/state" || t_fail 'open state'
pk_stop

t_grep 'pickers-grep-open opens the file of the match' 'bufname=a.txt' \
  "$work/open/state"
t_grep 'pickers-grep-open jumps to the matched line' 'cursor=2:1' \
  "$work/open/state"
t_nogrep 'pickers-grep-open closes the picker buffer' '*pickers-grep*' \
  "$work/open/state"

# --------------------------------------------------------------- grep-write

# One edited line per file: both files have to be saved, and the untouched
# lines of the edited files have to survive.
tree=$work/write/tree
pk_mkfixture "$tree"
cd "$tree"
pk_start "$work/write" "$(pk_init "edit -debug -scratch '*pickers-grep*'
execute-keys 'ia.txt:1:alpha one<ret>b.txt:1:delta four<esc>'
write -force '$work/write/src'
execute-keys '%sone<ret>cONE<esc>'
execute-keys '%sfour<ret>cFOUR<esc>'
pickers-grep-write
pk-test-dump '$work/write/dump'")"
pk_wait "$work/write/dump" || t_fail 'write dump'
pk_stop

printf 'alpha ONE\nbeta two\ngamma three\n' >"$work/write/a-expected"
printf 'delta FOUR\n' >"$work/write/b-expected"
t_file_is 'pickers-grep-write saves the first edited file' \
  "$work/write/a-expected" "$tree/a.txt"
t_file_is 'pickers-grep-write saves the second edited file' \
  "$work/write/b-expected" "$tree/b.txt"
t_grep 'the grep buffer survives the write' 'a.txt:1:alpha ONE' \
  "$work/write/dump"

# The new line is used as the search pattern that decides whether the file
# already holds it, so a line full of regex characters must not match the old
# text (an unescaped `|` would make `| 1$` match the old line and skip the
# write).
tree=$work/escape/tree
mkdir -p "$tree"
printf "it's a (test) [x] | 1\nsecond line\n" >"$tree/a.txt"
cd "$tree"
pk_start "$work/escape" "$(pk_init "edit -debug -scratch '*pickers-grep*'
execute-keys 'ia.txt:1:it'\"'\"'s a (test) [x] | 1<esc>'
write -force '$work/escape/src'
execute-keys '%stest<ret>'
execute-keys 'c(TEST)<esc>'
pickers-grep-write
pk-test-dump '$work/escape/dump'")"
pk_wait "$work/escape/dump" || t_fail 'escape dump'
pk_stop

printf "it's a ((TEST)) [x] | 1\nsecond line\n" >"$work/escape/expected"
t_file_is 'pickers-grep-write searches the new line literally' \
  "$work/escape/expected" "$tree/a.txt"

# A file that cannot be opened has to fail the command.
tree=$work/missing/tree
mkdir -p "$tree"
cd "$tree"
pk_start "$work/missing" "$(pk_init "edit -debug -scratch '*pickers-grep*'
execute-keys 'igone.txt:1:x<esc>'
write -force '$work/missing/src'
try %{ pickers-grep-write } catch %{ pk-test-write '$work/missing/failed' caught }
pk-test-write '$work/missing/done' done")"
pk_wait "$work/missing/done" || t_fail 'missing sync'
pk_stop

t_exists 'a missing file fails pickers-grep-write' "$work/missing/failed"

t_summary grep
