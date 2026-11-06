#!/usr/bin/env sh
# Unit tests: shell blocks are extracted from the plugin and run under dash
# with a fake Kakoune environment, so the path and quoting logic is exercised
# without starting an editor.
#
#   open   the body of _pickers-open-impl (path resolution for the pickers)
#   write  the body of pickers-grep-write (file paths and the search pattern)
#   info   the body of pickers-buffer-info (buffer list formatting)
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/color.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/assert.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/extract.sh

plugin=pickers.kak
tmp=$(mktemp -d "${TMPDIR:-/tmp}/pkunit.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export LC_ALL=C

extract_sh_block "$plugin" 'define-command -hidden _pickers-open-impl' "$tmp/open.sh"
extract_sh_block "$plugin" 'define-command pickers-grep-write' "$tmp/write.sh"
extract_sh_block "$plugin" 'define-command pickers-buffer-info' "$tmp/info.sh"
for block in open write info; do
  if [ ! -s "$tmp/$block.sh" ]; then
    t_fail "extracted the $block block"
    exit 1
  fi
done
t_ok 'every embedded shell block was extracted'

# GIT_DIR keeps `git rev-parse` out of a repository even when $TMPDIR happens
# to sit inside one, so the "no git root" branch is the one under test.
# open_at <buffer> <selection> <cbd> <cmd> [<append_root>]
open_at() {
  env -i PATH="$PATH" LC_ALL=C GIT_DIR="$tmp/no-git" \
    kak_selection="$2" \
    kak_opt__pickers_cbd="$3" \
    dash "$tmp/open.sh" "$1" '' "$4" "${5:-}"
}

# --------------------------------------------------------------- open block

out=$(cd "$tmp" && open_at '*pickers-file*' 'sub/b file.txt' '' 'edit -existing')
{
  printf 'edit -existing sub/b\\ file.txt\n'
  printf 'delete-buffer *pickers-file*\n'
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'a relative path is kept and its spaces are escaped' \
  "$tmp/expected" "$tmp/out"

out=$(cd "$tmp" && open_at '*pickers-file*' 'sub/b file.txt' '/base' 'edit -existing')
{
  printf 'edit -existing /base/sub/b\\ file.txt\n'
  printf 'delete-buffer *pickers-file*\n'
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'a relative path is resolved against _pickers_cbd' \
  "$tmp/expected" "$tmp/out"

out=$(cd "$tmp" && open_at '*pickers-buffer*' '*other*' '/base' 'buffer' true)
{
  printf 'buffer *other*\n'
  printf 'delete-buffer *pickers-buffer*\n'
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'a buffer name is passed through unresolved' \
  "$tmp/expected" "$tmp/out"

# -------------------------------------------------------------- write block

# write_at <quoted-register-c> <file> <cbd>
write_at() {
  env -i PATH="$PATH" LC_ALL=C GIT_DIR="$tmp/no-git" \
    kak_reg_f="$2" \
    kak_quoted_reg_c="$1" \
    kak_opt__pickers_cbd="$3" \
    dash "$tmp/write.sh"
}

out=$(cd "$tmp" && write_at "'alpha HELLO world'" 'a.txt' '')
{
  printf 'edit -existing a.txt\n'
  printf "set-register s 'alpha HELLO world'\n"
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'the new line becomes the search pattern unchanged' \
  "$tmp/expected" "$tmp/out"

# the pattern is a regex, so its characters have to be escaped; the register
# itself keeps the plain text
out=$(cd "$tmp" && write_at "'a (b) [c] | d'" 'a.txt' '')
{
  printf 'edit -existing a.txt\n'
  printf "set-register s 'a \\(b\\) \\[c\\] \\| d'\n"
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'regex characters in the new line are escaped' \
  "$tmp/expected" "$tmp/out"

# kakoune quotes the register already, so a quote in the line stays doubled
# (that is how a quoted string carries it) and is not wrapped again
out=$(cd "$tmp" && write_at "'it''s a (test)'" 'a.txt' '')
{
  printf 'edit -existing a.txt\n'
  printf "set-register s 'it''s a \\(test\\)'\n"
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'a quote in the new line survives the quoting' \
  "$tmp/expected" "$tmp/out"

out=$(cd "$tmp" && write_at "'x'" 'a.txt' '/base')
{
  printf 'edit -existing /base/a.txt\n'
  printf "set-register s 'x'\n"
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'the edited file is resolved against _pickers_cbd' \
  "$tmp/expected" "$tmp/out"

# --------------------------------------------------------------- info block

out=$(env -i PATH="$PATH" LC_ALL=C \
  kak_quoted_opt__pickers_buflist="'a.txt' 'b.txt'" \
  kak_opt__pickers_current_buffer='b.txt' \
  dash "$tmp/info.sh")
{
  printf '  1 a.txt\n'
  printf '> 2 b.txt\n'
} >"$tmp/expected"
printf '%s\n' "$out" >"$tmp/out"
t_file_is 'the current buffer is marked in the buffer list' \
  "$tmp/expected" "$tmp/out"

t_summary unit
