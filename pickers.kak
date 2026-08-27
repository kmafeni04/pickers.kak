provide-module pickers %{
  declare-option -docstring "Delay before picker command is called again when typing" \
    int pickers_timeout 50

  declare-option -docstring "Limit number of entries returned in *pickers-file* buffer" \
    str pickers_file_result_limit "-0" # "-0" means no limit, see `head --help` for explanation of the `-n` flag

  declare-option -docstring "Select all grep matches in the buffer" \
    bool pickers_grep_select_matches false
  declare-option -docstring "Set the '/' register after grep" \
    bool pickers_grep_set_slash_register true
  declare-option -docstring "Save last search to be used as init of next grep" \
    bool pickers_grep_save_last_search true
  declare-option -docstring "Limit number of entries returned in *pickers-grep* buffer" \
    str pickers_grep_result_limit "-0"

  declare-option -hidden str-list _pickers_buflist
  declare-option -hidden str _pickers_previous_buffer
  declare-option -hidden str _pickers_current_buffer
  declare-option -hidden str _pickers_cbd
  declare-option -hidden str _pickers_grep_last_search
  declare-option -hidden str _pickers_grep_current_search

  hook global WinDisplay .* %{
    try %{
      evaluate-commands %sh{
        case "$kak_bufname" in
          "*pickers-buffer*"|"*pickers-file*"|"*pickers-grep*") printf 'fail\n' ;;
        esac
      }
      set-option global _pickers_previous_buffer %opt{_pickers_current_buffer}
      set-option global _pickers_current_buffer %val{bufname}
    }
  }

  define-command -hidden _pickers-set-buflist %{
    set-option global _pickers_buflist
    evaluate-commands -no-hooks -buffer * %{
      try %{
        evaluate-commands %sh{
          case "$kak_bufname" in
            "*pickers-buffer*"|"*pickers-file*"|"*pickers-grep*") printf 'fail\n' ;;
          esac
        }
        set-option -add global _pickers_buflist "%val{bufname}"
      }
    }
  }

  define-command -hidden _pickers-assert-buffer -params 1 %{
    evaluate-commands %sh{
      [ ! "$kak_bufname" = "$1" ] && echo "fail 'Not in $1 buffer'"
    }
  }

  define-command -hidden _pickers-on-change-impl -params 2..3 %{
    fifo -name %arg{1} -script %{
      if [ -z "$kak_quoted_text" ]; then
        [ -z "$2" ] && exit
        kak_quoted_text="$2" # Initial text
      fi

      git_base_dir=$(sh -c "git rev-parse --show-toplevel 2>/dev/null")

      [ -n "$git_base_dir" ] && cd "$git_base_dir"
      [ -n "$kak_opt__pickers_cbd" ] && cd "$kak_opt__pickers_cbd"

      eval "$1"
    } -- %arg{2} %arg{3}
    set-option global _pickers_grep_current_search ''
    evaluate-commands %sh{
      if [ -z "$kak_quoted_text" ]; then
        [ -z "$3" ] && exit
        kak_quoted_text="$3" # Initial text
      fi

      query=$(printf '%s' "$kak_quoted_text" | sed "s/'/''/g;s/(/\\\\(/g;s/)/\\\\)/g;s/{/\\\\{/g;s/}/\\\\}/g")
      printf "set-option window _pickers_grep_current_search '%s'\n" "$query"
      if [ "$kak_quoted_text" = '.' ]; then
        exit
      fi
      printf "try %%{ add-highlighter -override window/pickers_match regex '(?i)%s' 0:cyan+bu }\n" "$query"
    }
  }

  define-command -hidden _pickers-open-impl -params 3..4 %{
    _pickers-assert-buffer %arg{1}
    execute-keys %arg{2} # match_keys
    evaluate-commands %sh{
      buffer="$1"
      cmd="$3"
      append_root="$4"
      file="$(printf '%s' "$kak_selection" | sed 's|\ |\\ |g')"

      if [ -z "$append_root" ]; then
        file="$(printf '%s' "$file" | sed 's|:| |g')"
        git_base_dir="$(git rev-parse --show-toplevel 2>/dev/null)"
        if [ -n "$kak_opt__pickers_cbd" ]; then
          file="$kak_opt__pickers_cbd/$file"
        elif [ -n "$git_base_dir" ]; then
          file="$git_base_dir/$file"
        fi
      fi

      printf "%s %s\n" "$cmd" "$file"
      printf '%s\n' "delete-buffer $buffer"
    }
  }

  define-command pickers-buffer-info \
  -docstring "Open and Info box showing all open buffers" \
  %{
    _pickers-set-buflist
    info -title 'buffer-info' %sh{
      count=1
      eval "set -- $kak_quoted_opt__pickers_buflist"
      while [ $# -gt 0 ]; do
        line="$1"

        if [ "$line" = "$kak_opt__pickers_current_buffer" ]; then
          line="> $count $line"
        else
          line="  $count $line"
        fi
        printf '%s\n' "$line"
        count=$((count + 1))

        shift
      done
    }
  }

  define-command pickers-buffer-alternate \
  -docstring "Jump between the last 2 opened buffers" \
  %{
    buffer %opt{_pickers_previous_buffer}
  }

  define-command pickers-buffer-open \
  -docstring "Within the *pickers-buffer* buffer, open the buffer under the cursor" \
  %{
    _pickers-open-impl '*pickers-buffer*' '<semicolon>x<a-:><a-semicolon>4L' 'buffer' true
  }

  define-command -hidden _pickers-buffer-on-change %{
    _pickers-on-change-impl '*pickers-buffer*' %{
      count=1
      buflist=""
      eval "set -- $kak_quoted_opt__pickers_buflist"
      (while [ $# -gt 0 ]; do
        line="$1"

        if [ "$line" = "$kak_opt__pickers_current_buffer" ]; then
          line="> $count $line"
        elif [ "$line" = "$kak_opt__pickers_previous_buffer" ]; then
          line="< $count $line"
        else
          line="  $count $line"
        fi
        printf '%s\n' "$line"
        count=$((count + 1))

        shift
      done) | grep -iE "$kak_quoted_text"
    } '.'
  }

  define-command pickers-buffer -docstring "Open the buffer picker" %{
    _pickers-set-buflist
    _pickers-buffer-on-change
    set-option window idle_timeout %opt{pickers_timeout}
    prompt "buffer:" -on-abort %{
      delete-buffer '*pickers-buffer*'
      unset-option window idle_timeout
    } \
    -on-change _pickers-buffer-on-change \
    %{
      unset-option window idle_timeout
      evaluate-commands %{
        execute-keys '%'
        evaluate-commands %sh{
          if [ ! "$kak_cursor_line" -eq 1 ]; then
            printf '%s\n' "execute-keys gg"
            exit
          fi
          printf '%s\n' "pickers-buffer-open"
        }
      }
    }
  }

  define-command pickers-file-open \
  -docstring "Within the *pickers-file* buffer, open the file under the cursor" \
  %{
    _pickers-open-impl '*pickers-file*' '<semicolon>x_' 'edit -existing'
  }

  define-command -hidden _pickers-file-on-change %{
    _pickers-on-change-impl '*pickers-file*' %{
      recurse_git() {
        dir="$1"

        [ -n "$dir" ] && cd "$dir"

        files=$(
          sh -c '(
                  git ls-files --cached --modified --others --deduplicate --exclude-standard 2>/dev/null || \
                  find . -type f | sed "s|\./||g"
                ) | \
                while read -r file; do
                  if [ -f "$file" ]; then
                    printf "%s\n" "$file"
                  fi
                done'
        ) || return 1

        IFS="$(printf '\n\b')"
        for file in $files; do
          case "$file" in
          */)
            recurse_git "$file" || return 1
            dir=""
            ;;
          *) printf '%s\n' "${dir}${file}" ;;
          esac
        done

        [ -n "$dir" ] && cd ".."

        return 0
      }

      (recurse_git || find . -type f 2>/dev/null | sed 's|^\./||g') |
        grep -iE "$kak_quoted_text" |
        head -n $kak_opt_pickers_file_result_limit
    } '.'
  }

  define-command -hidden _pickers-file-impl -params ..1 %{
    set-option global _pickers_cbd %arg{1}
    _pickers-file-on-change
    set-option window idle_timeout %opt{pickers_timeout}
    prompt "file:" -on-abort %{
      delete-buffer '*pickers-file*'
      unset-option window idle_timeout
    } \
    -on-change _pickers-file-on-change \
    %{
      unset-option window idle_timeout
      evaluate-commands %{
        execute-keys '%'
        evaluate-commands %sh{
          if [ ! "$kak_cursor_line" -eq 1 ]; then
            printf '%s\n' "execute-keys gg"
            exit
          fi
          printf '%s\n' "pickers-file-open"
        }
      }
    }
  }

  define-command pickers-file \
  -docstring "pickers-file [<direcotry>]: Open the file picker at $CWD or <directory>" \
  -params ..1 \
  %{
    _pickers-file-impl %arg{1}
  }
  complete-command pickers-file file

  define-command pickers-file-cbd \
  -docstring "Open the file picker at the current buffers direcotry" \
  %{
    _pickers-file-impl %sh{ [ -n "$kak_buffile" ] && dirname "$kak_buffile" }
  }

  define-command pickers-grep-open \
  -docstring "Within the *pickers-grep* buffer, open the file under the cursor" \
  %{
    _pickers-open-impl '*pickers-grep*' '<semicolon>xs^.+:[0-9]+(:[0-9]+)?<ret>' 'edit -existing'
  }

  define-command pickers-grep-write \
  -docstring "After making changes to the *pickers-grep*, save changes to the respective files" \
  %{
    _pickers-assert-buffer "*pickers-grep*"
    set-option global _pickers_buflist
    evaluate-commands -no-hooks -buffer * %{
      set-option -add global _pickers_buflist "%val{bufname}"
    }
    evaluate-commands -save-regs '/flsce' -draft %{
      echo "Updating files..."
      execute-keys '%s^([^\n]+?):(\d+)(?::\d+)?:([^\n]*)$<ret>'
      evaluate-commands -itersel %{
        set-register f %reg{1}
        set-register l %reg{2}
        set-register c %reg{3}
        set-register e 0

        try %{
          evaluate-commands -draft %{
            evaluate-commands %sh{
              file="$kak_reg_f"
              git_base_dir="$(git rev-parse --show-toplevel 2>/dev/null)"
              if [ -n "$kak_opt__pickers_cbd" ]; then
                file="$kak_opt__pickers_cbd/$file"
              elif [ -n "$git_base_dir" ]; then
                file="$git_base_dir/$file"
              fi
              printf "edit -existing %s\n" "$file"

              kak_reg_s=$(printf '%s' "$kak_quoted_reg_c" | sed "s/'/''/g;s/(/\\\\(/g;s/)/\\\\)/g;s/{/\\\\{/g;s/}/\\\\}/g")
              kak_reg_s=$(printf '%s' "$kak_quoted_reg_c" | sed 's/|/\\|/g')
              printf "set-register s '%s'\n" "$kak_reg_s"
            }

            execute-keys "%reg{l}gx"

            try %{
              set-register / "%reg{s}$"
              execute-keys 's<ret>'
            } catch %{
              execute-keys '"cR'
              write
            }

            evaluate-commands %sh{
              found=false
              for bufname in $kak_quoted_opt__pickers_buflist; do
                if [ "$bufname" = "$kak_quoted_bufname" ]; then
                  found=true
                  break
                fi
              done
              if [ "$found" = "false" ]; then
                printf "delete-buffer\n"
              fi
            }
          }
        } catch %{
          set-register e %sh{ printf '%d\n' "$((kak_main_reg_e + 1))" }
          echo -debug "pickers-grep-write: Failed to edit %reg{f}: %val{error}"
        }
      }
      evaluate-commands %sh{
        if [ "$kak_main_reg_e" -gt 0 ]; then
          printf "fail 'Some files were not changed, see *debug* buffer'\n"
          exit
        fi
      }
    }
    echo 'Updated files'
  }

  define-command -hidden _pickers-grep-on-change %{
    _pickers-on-change-impl '*pickers-grep*' %{
      if [ -n "$git_base_dir" ]; then
        (
          (git ls-files --cached --modified --others --deduplicate --exclude-standard 2>/dev/null || find . -type f | sed "s|\./||g") |
            while read -r file; do
              if [ -f "$file" ]; then
                printf "%s\n" "$file"
              fi
            done
        ) | xargs $kak_opt_grepcmd "$kak_quoted_text" 2>/dev/null
      else
        grep -RIl '.' 2>/dev/null |
          head -n $kak_opt_pickers_grep_result_limit |
          sed 's|^\./||g' |
          xargs $kak_opt_grepcmd "$kak_quoted_text" 2>/dev/null
      fi
    }
  }

  define-command -hidden _pickers-grep-impl -params ..1 %{
    set-option global _pickers_cbd %arg{1}
    _pickers-grep-on-change
    set-option window filetype grep
    set-option window idle_timeout %opt{pickers_timeout}
    prompt "grep:" -init "%opt{_pickers_grep_last_search}" \
    -on-abort %{
      unset-option window idle_timeout
      delete-buffer '*pickers-grep*'
    } \
    -on-change _pickers-grep-on-change \
    %{
      evaluate-commands %sh{
        if [ "$kak_opt_pickers_grep_save_last_search" = true ]; then
          printf '%s\n' "_pickers-grep-on-change"
        fi
      }
      set-option global _pickers_grep_last_search ''
      unset-option window idle_timeout
      evaluate-commands %sh{
        if [ "$kak_opt_pickers_grep_set_slash_register" = true ]; then
          printf '%s\n' "set-register / %opt{_pickers_grep_current_search}"
        fi
        if [ "$kak_opt_pickers_grep_save_last_search" = true ]; then
          grep_query=$(printf '%s' "$kak_text" | sed "s/'/''/g")
          printf "set-option global _pickers_grep_last_search '%s'\n" "$grep_query"
        fi
      }
      execute-keys '%'
      evaluate-commands -save-regs '/' %sh{
        printf '%s\n' "set-register / %opt{_pickers_grep_current_search}"
        if [ "$kak_cursor_line" -eq 1 ] && [ "$kak_cursor_column" -gt 1 ]; then
          printf '%s\n' "pickers-grep-open"
          printf '%s\n' "execute-keys 'xs<ret>'"
          exit
        fi
        printf '%s\n' "execute-keys gg"
        if [ "$kak_opt_pickers_grep_select_matches" = true ]; then
          printf '%s\n' "try %§
            execute-keys '%<a-s>s[^:]*:[0-9]+:([0-9]+:)?<ret>l<a-l>'
            execute-keys 's<ret>)'
          §"
        elif [ "$kak_cursor_column" -gt 1 ]; then
          printf '%s\n' "execute-keys n"
        fi
      }
    }
  }

  define-command pickers-grep -params ..1 \
  -docstring "pickers-grep [<direcotry>]: Open the grep picker at $CWD or <directory>" \
  %{
    _pickers-grep-impl %arg{1}
  }
  complete-command pickers-grep file

  define-command pickers-grep-cbd \
  -docstring "Open the grep picker at the current buffers direcotry" \
  %{
    _pickers-grep-impl %sh{ [ -n "$kak_buffile" ] && dirname "$kak_buffile" }
  }
}

require-module pickers
