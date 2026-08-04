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
map global pickers n ':pickers-file /home/kome/Documents/Nextcloud/Notes/<ret>' -docstring 'Open fuzzy file picker in notes directory'
map global pickers o ':pickers-file-cbd<ret>' -docstring "Open fuzzy file picker in current buffer's directory"
map global pickers g ':pickers-grep<ret>' -docstring "Open grep picker in git root"
map global pickers G "<dquote>/y:pickers-grep<ret>" -docstring "Open grep picker in git root with selection as init"
map global pickers <a-g> ':pickers-grep-cbd<ret>' -docstring "Open grep picker in buffer's directory"
map global pickers <a-G> "<dquote>/y:pickers-grep-cbd<ret>" -docstring "Open grep picker in buffer's directory with selection as init"

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
