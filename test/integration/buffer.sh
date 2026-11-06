#!/usr/bin/env sh
# The buffer commands: pickers-buffer-open switches to the buffer named on the
# picker line (past the marker and the count), and pickers-buffer-alternate
# goes back to the buffer that was displayed before the current one.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # harness sources the shared helpers
. test/integration/harness.sh
pk_require_kak

export LC_ALL=C
work=$(mktemp -d "${TMPDIR:-/tmp}/pktest.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM

printf 'a\n' >"$work/a.txt"
printf 'b\n' >"$work/b.txt"

pk_start "$work/open" "$(pk_init "edit -debug '$work/a.txt'
edit -debug '$work/b.txt'
set-option global _pickers_buflist '$work/a.txt' '$work/b.txt'
edit -debug -scratch '*pickers-buffer*'
execute-keys 'i> 1 $work/a.txt<ret>  2 $work/b.txt<esc>'
write -force '$work/list'
execute-keys '2G'
pickers-buffer-open
pk-test-state '$work/open/state'")"
pk_wait "$work/open/state" || t_fail 'buffer open state'
pk_stop

t_grep 'pickers-buffer-open opens the buffer on the line' \
  "bufname=$work/b.txt" "$work/open/state"
t_nogrep 'pickers-buffer-open closes the picker buffer' '*pickers-buffer*' \
  "$work/open/state"

pk_start "$work/alternate" "$(pk_init "edit -debug '$work/a.txt'
edit -debug '$work/b.txt'
pickers-buffer-alternate
pk-test-state '$work/alternate/state'")"
pk_wait "$work/alternate/state" || t_fail 'alternate state'
pk_stop

t_grep 'pickers-buffer-alternate returns to the previous buffer' \
  "bufname=$work/a.txt" "$work/alternate/state"
t_grep 'the previous buffer is tracked when the buffer changes' \
  "previous=$work/b.txt" "$work/alternate/state"

t_summary buffer
