#!/usr/bin/env sh
# Runs every integration script against a headless Kakoune; each one owns its
# temp directory and its sessions, so they run one after another.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # color.sh is linted separately
. test/color.sh

command -v kak >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip kak not installed')"
  exit 0
}

n=0
failed=0
for f in test/integration/*.sh; do
  case $f in */run.sh|*/harness.sh) continue ;; esac
  printf '\n%s\n' "$(cm_bold "${f##*/}")"
  sh "$f" || failed=$((failed + 1))
  n=$((n + 1))
done
printf '\n%s\n' "$(cm_green "ok $n integration scripts")"
[ "$failed" -eq 0 ]
