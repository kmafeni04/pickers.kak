#!/usr/bin/env sh
# Extract the shell body of a %sh{...} block from the plugin, so unit tests can
# exercise it under dash without Kakoune.
#
# Kakoune ends a %{...} body at the brace that balances the opening one, and it
# counts braces even inside quotes, so counting braces here matches what
# Kakoune itself parses.
#
# extract_sh_block <plugin> <anchor> <out>
#   <anchor> is a fixed string on the line that carries "%sh{" (use a unique
#   one when the command holds several blocks).
extract_sh_block() {
  start=$(grep -nF -- "$2" "$1" | head -1 | cut -d: -f1)
  [ -n "$start" ] || return 1
  awk -v s="$start" '
    NR < s { next }
    { buf = buf $0 "\n" }
    END {
      p = index(buf, "%sh{")
      if (p == 0) { exit 1 }
      body = substr(buf, p + 4)
      n = length(body)
      depth = 1
      i = 1
      while (i <= n && depth > 0) {
        c = substr(body, i, 1)
        if (c == "{") depth++
        else if (c == "}") depth--
        i++
      }
      if (depth != 0) { exit 1 }
      printf "%s", substr(body, 1, i - 2)
    }
  ' "$1" >"$3"
}

# extract_all_sh_blocks <plugin> <dir>: write every %sh{...} body to
# <dir>/block.NNN, for a syntax check of the whole plugin.
extract_all_sh_blocks() {
  mkdir -p "$2" || return 1
  awk -v dir="$2" '
    { buf = buf $0 "\n" }
    END {
      n = length(buf)
      i = 1
      idx = 0
      while ((p = index(substr(buf, i), "%sh{")) > 0) {
        start = i + p + 4
        depth = 1
        j = start
        while (j <= n && depth > 0) {
          c = substr(buf, j, 1)
          if (c == "{") depth++
          else if (c == "}") depth--
          j++
        }
        if (depth != 0) { exit 1 }
        idx++
        file = sprintf("%s/block.%03d", dir, idx)
        printf "%s", substr(buf, start, j - 1 - start) > file
        close(file)
        i = j
      }
      printf "%d\n", idx
    }
  ' "$1"
}
