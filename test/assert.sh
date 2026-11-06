#!/usr/bin/env sh
# Minimal assertion helpers shared by the test scripts.  Sourced after
# test/color.sh; the counters live in the sourcing shell.

t_passes=0
t_fails=0

t_ok() {
  printf '%s\n' "$(cm_green "ok $1")"
  t_passes=$((t_passes + 1))
}

t_fail() { # name [detail]
  printf '%s\n' "$(cm_red "FAIL $1")"
  if [ $# -gt 1 ]; then printf '%s\n' "$2"; fi
  t_fails=$((t_fails + 1))
}

t_file_is() { # name expected-file actual-file
  if diff -u "$2" "$3"; then t_ok "$1"; else t_fail "$1"; fi
}

t_grep() { # name fixed-string file
  if grep -qF -- "$2" "$3"; then
    t_ok "$1"
  else
    t_fail "$1" "  missing: $2"
  fi
}

t_nogrep() { # name fixed-string file
  if grep -qF -- "$2" "$3"; then
    t_fail "$1" "  unexpected: $2"
  else
    t_ok "$1"
  fi
}

t_exists() { # name path
  if [ -e "$2" ]; then t_ok "$1"; else t_fail "$1" "  missing path: $2"; fi
}

t_summary() { # name
  if [ "$t_fails" -gt 0 ]; then
    printf '%s\n' "$(cm_red "FAIL $t_fails of $((t_passes + t_fails)) checks in $1")"
    exit 1
  fi
  if [ "$t_passes" -eq 1 ]; then
    printf '%s\n' "$(cm_green "ok 1 check in $1")"
  else
    printf '%s\n' "$(cm_green "ok $t_passes checks in $1")"
  fi
}
