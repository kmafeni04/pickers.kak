#!/usr/bin/env sh
# pickers.kak local test runner (POSIX; also run as: dash test/run.sh)
set -eu
case $0 in */*) cd "${0%/*}" ;; esac # POSIX dirname substitute

# shellcheck disable=SC1091  # color.sh is linted separately
. ./color.sh

# print a bold section header with a blank line before it
header() {
  printf '\n%s\n' "$(cm_bold "$1")"
}

# run_one <test>: print its header and run it
run_one() {
  case $1 in
    lint)        header 'Lint:';              dash ./lint.sh ;;
    unit)        header 'Unit tests:';        dash ./unit/run.sh ;;
    integration) header 'Integration tests:'; ./integration/run.sh ;;
  esac
}

cmd=${1:-all}
case $cmd in
  lint | unit | integration) run_one "$cmd" ;;
  all) for t in lint unit integration; do run_one "$t"; done ;;
  *)
    printf 'usage: test/run.sh [lint|unit|integration|all]\n' >&2
    exit 2
    ;;
esac
