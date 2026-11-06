#!/usr/bin/env sh
# Headless Kakoune harness for the pickers.kak tests: a real window driven
# through the json ui, so no terminal is needed.  Sourced from the repo root by
# the integration scripts; it pulls in the shared helpers itself.
#
# Lifecycle: pk_start, then pk_wait as needed, then pk_stop.  The commands to
# drive are handed to pk_start, so nothing has to be typed at a running client.
#
# The plugin's prompt-driven pickers are not driven here: the harness starts kak
# with `-n`, which skips Kakoune's rc and with it the `fifo` module the prompts
# read from.  The integration tests therefore build the picker buffers
# themselves and exercise the commands that run inside them, which is where the
# logic lives.

# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/color.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/assert.sh

pk_require_kak() {
  command -v kak >/dev/null 2>&1 || {
    printf '%s\n' "$(cm_yellow 'skip kak not installed')"
    exit 0
  }
}

# absolute: the test scripts cd into their fixtures, and kak resolves `source`
# against its own working directory
PK_PLUGIN=${PK_PLUGIN:-$PWD/pickers.kak}
PK_KAK=${PK_KAK:-$(command -v kak 2>/dev/null || true)}
PK_KAK=${PK_KAK:-kak}
pk_seq=0
pk_work=
pk_pid=

# Test-only commands added to every session.
#
#   pk-test-dump <file>   write the current buffer to <file>
#   pk-test-state <file>  write the buffer state to <file>
#
# The tests build the picker buffers themselves (see the note at the top) as
# scratch buffers filled with `execute-keys`.  Such a buffer is modified, and
# Kakoune refuses to delete a modified buffer, so the inits save it with
# `write -force <path>` first: that clears the flag the way the real prompt
# buffer is never set.
#   pk-test-write <file> <val>  write <val> to <file>
pk_test_commands() {
  cat <<'EOF'
define-command -hidden pk-test-dump -params 1 %{ write %arg{1} }
define-command -hidden pk-test-state -params 1 %{ nop %sh{
  { echo "bufname=$kak_bufname"
    echo "cursor=$kak_cursor_line:$kak_cursor_column"
    echo "buffers=$kak_quoted_opt__pickers_buflist"
    echo "open=$kak_quoted_buflist"
    echo "current=$kak_opt__pickers_current_buffer"
    echo "previous=$kak_opt__pickers_previous_buffer"
  } > "$1" } }
define-command -hidden pk-test-write -params 2 %{ nop %sh{ printf '%s' "$2" > "$1" } }
EOF
}

# pk_init <extra commands> -> full -e string
pk_init() {
  printf "source '%s'\n%s\n%s\n" "$PK_PLUGIN" "$(pk_test_commands)" "$1"
}

# pk_start <workdir> <init commands>; kak inherits this script's directory
pk_start() {
  pk_work=$1
  pk_seq=$((pk_seq + 1))
  mkdir -p "$pk_work" || return 1
  mkfifo "$pk_work/in" || return 1
  "$PK_KAK" -n -s "pktest-$$-$pk_seq" -ui json -e "$2" \
    <"$pk_work/in" >"$pk_work/out.json" 2>"$pk_work/err" &
  pk_pid=$!
  sleep 1
  if ! kill -0 "$pk_pid" 2>/dev/null; then
    t_fail 'kak failed to start' "$(cat "$pk_work/err")"
    return 1
  fi
  exec 3>"$pk_work/in"
}

# pk_wait <path>: wait (up to ~10s) until the session wrote <path>
pk_wait() {
  pk_i=0
  while [ ! -s "$1" ]; do
    pk_i=$((pk_i + 1))
    if [ "$pk_i" -gt 10 ]; then return 1; fi
    sleep 1
  done
}

# pk_stop: close the session and fail the case if kak wrote to stderr
pk_stop() {
  exec 3>&-
  wait "$pk_pid" 2>/dev/null || true
  if [ -s "$pk_work/err" ]; then
    t_fail 'kak stderr' "$(cat "$pk_work/err")"
    return 1
  fi
}

# pk_mkfixture <dir>: the fixture tree the grep/file tests use
pk_mkfixture() {
  mkdir -p "$1/sub" || return 1
  printf 'alpha one\nbeta two\ngamma three\n' >"$1/a.txt"
  printf 'delta four\n' >"$1/b.txt"
  printf 'inner\n' >"$1/sub/b file.txt"
}
