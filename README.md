# pickers.kak

A set of file pickers for kakoune using grep as the interface

[![asciicast](https://asciinema.org/a/ZM3LnRugTnJGm6V8.svg)](https://asciinema.org/a/ZM3LnRugTnJGm6V8)

## Dependencies
- git: (optional: will fallback to `find`)
- grep

## Installation
Copy [pickers.kak](./pickers.kak) into your autoload directory

## Available Options

- `pickers_timeout`: Delay before picker command is called again when typing
- `pickers_file_result_limit`: Limit number of entries returned in *pickers-file* buffer
- `pickers_grep_select_matches`: Select all grep matches in the buffer
- `pickers_grep_set_slash_register`: Set the '/' register after grep
- `pickers_grep_save_last_search`: Save last search to be used as init of next grep
- `pickers_grep_result_limit`: Limit number of entries returned in *pickers-grep* buffer

## Suggested Keymaps
```kak
declare-user-mode pickers
map global user p ':enter-user-mode pickers<ret>' -docstring 'pickers mode'
map global pickers b ':pickers-buffer<ret>' -docstring 'Open fuzzy buffer picker'
map global pickers i ':pickers-buffer-info<ret>' -docstring 'Show currently open buffers'
map global pickers a ':pickers-buffer-alternate<ret>' -docstring 'Switch to previously opened buffer'
map global pickers f ':pickers-file<ret>' -docstring 'Open fuzzy file picker in git root or current working directory'
map global pickers o ':pickers-file-cbd<ret>' -docstring "Open fuzzy file picker in current buffer's directory"
map global pickers g ':pickers-grep<ret>' -docstring "Open grep picker in git root"
map global pickers <a-g> ':pickers-grep-cbd<ret>' -docstring "Open grep picker in buffer's directory"

hook global WinCreate \*pickers-grep\* %{
  map window normal <ret> ':pickers-grep-open<ret>'
  map window normal <a-ret> "%%s<ret>)" -docstring "Select all matched grep text"
  alias window write pickers-grep-write
  alias window w pickers-grep-write
}
hook global WinCreate \*pickers-file\* %{
  map window normal <ret> ':pickers-file-open<ret>'
}
hook global WinCreate \*pickers-buffer\* %{
  map window normal <ret> ':pickers-buffer-open<ret>'
}
```

## Tests

No terminal is needed: the integration cases drive a headless `kak` through
the json ui, so nothing has to be typed by hand.

```sh
./test/run.sh               # lint, unit and integration
./test/run.sh lint          # static checks only
./test/run.sh unit          # shell blocks under dash, no Kakoune
./test/run.sh integration   # headless Kakoune sessions
```

- `test/lint.sh` checks that the braces balance, that every `%sh{}` block
  parses under dash, that public commands carry a `-docstring`, that every
  `_pickers_` option is declared, that the commands mapped in this README
  exist, and that the test scripts are shellcheck clean.
- `test/unit/run.sh` extracts the path and quoting shell blocks from the
  plugin and runs them under dash with a fake Kakoune environment.
- `test/integration/*.sh` build a picker buffer, run the commands that act on
  it and assert on the resulting buffers and files.

The picker prompts themselves are not driven: the harness starts kak with `-n`,
which skips Kakoune's rc and with it the `fifo` module the prompts read from.
The tests exercise the commands that run inside the picker buffers instead.

`dash` is required for the lint and unit cases, `kak` for the integration
cases, and `shellcheck` is optional. Scratch files go to `$TMPDIR` (default
`/tmp`).
