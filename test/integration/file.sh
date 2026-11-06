#!/usr/bin/env sh
# pickers-file-open: the file under the cursor is opened (spaces in the name
# included) and the picker buffer is closed.  Relative paths resolve against
# _pickers_cbd when it is set.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # harness sources the shared helpers
. test/integration/harness.sh
pk_require_kak

export LC_ALL=C
work=$(mktemp -d "${TMPDIR:-/tmp}/pktest.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM

tree=$work/tree
pk_mkfixture "$tree"

# run from the repo root with _pickers_cbd, so the path in the buffer is not
# resolved against kakoune's own directory
pk_start "$work/cbd" "$(pk_init "set-option global _pickers_cbd '$tree'
edit -debug -scratch '*pickers-file*'
execute-keys 'ia.txt<ret>sub/b file.txt<esc>'
write -force '$work/src'
execute-keys '2G'
pickers-file-open
pk-test-state '$work/cbd/state'")"
pk_wait "$work/cbd/state" || t_fail 'cbd state'
pk_stop

t_grep 'a relative path resolves against _pickers_cbd' \
  "bufname=$tree/sub/b file.txt" "$work/cbd/state"

# the same line from inside the fixture: no _pickers_cbd, no git repository
cd "$tree"
pk_start "$work/plain" "$(pk_init "edit -debug -scratch '*pickers-file*'
execute-keys 'ia.txt<ret>sub/b file.txt<esc>'
write -force '$work/src'
execute-keys '2G'
pickers-file-open
pk-test-state '$work/plain/state'")"
pk_wait "$work/plain/state" || t_fail 'plain state'
pk_stop

t_grep 'a space in the file name is escaped' \
  'bufname=sub/b file.txt' "$work/plain/state"
t_nogrep 'pickers-file-open closes the picker buffer' '*pickers-file*' \
  "$work/plain/state"

t_summary file
