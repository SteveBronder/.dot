##! [db] gopg
##! Desc: Become the postgres superuser in an interactive login shell.
##! Usage: gopg
##! Inputs: none
##! Output: switches to user `postgres` with a login shell.
function gopg() {
  sudo -i -u postgres
}

##! [db] gopsql
##! Desc: Open psql as the postgres user.
##! Usage: gopsql [psql-args...]
##! Inputs: optional psql flags (e.g., -d dbname)
##! Output: launches psql connected as `postgres`.
function gopsql() {
    sudo -u postgres psql
}

##! [python] envact
##! Desc: Activate a Python virtualenv from a project path or a direct venv path.
##! Usage: envact /path/to/project | /path/to/venv | /path/to/venv/bin/activate
##! Inputs: a project dir containing `.venv/`, or a venv dir containing `bin/activate`, or the activate file itself.
##! Output: sources the venv; prints the activated prefix; nonzero exit on failure.
envact() {
    local target="$1"

    if [[ -z "$target" ]]; then
        echo "❌ Missing argument: path to project or venv"
        return 1
    fi

    # Allow passing the activate file directly
    if [[ -f "$target" && "$target" == */bin/activate ]]; then
        # shellcheck disable=SC1090
        source "$target"
    # If the user pointed to a venv dir, use its bin/activate
    elif [[ -d "$target" && -f "$target/bin/activate" ]]; then
        # shellcheck disable=SC1091
        source "$target/bin/activate"
    # If the user pointed to a project dir, try .venv/bin/activate
    elif [[ -d "$target/.venv" && -f "$target/.venv/bin/activate" ]]; then
        # shellcheck disable=SC1091
        source "$target/.venv/bin/activate"
    else
        echo "❌ No activate script found in:"
        echo "   $target/bin/activate"
        echo "   or"
        echo "   $target/.venv/bin/activate"
        return 1
    fi

    echo "✅ Activated virtualenv at: $(python -c 'import sys; print(sys.prefix)')"
}

##! [util] onchange
##! Desc: Watch a file or directory and run a command on changes.
##! Usage:
##!   onchange <file-or-dir> <command...>
##! Examples:
##!   onchange src/ "make -j16"
##!   onchange pyproject.toml pytest tests/
##! Notes:
##!   - Requires `inotifywait` from the `inotify-tools` package (Linux).
##!   - Triggers on close_write, create, move, and delete events.
onchange() {
  if ! command -v inotifywait >/dev/null 2>&1; then
    echo "onchange: please install inotify-tools (inotifywait not found)" >&2
    return 1
  fi

  local target="$1"; shift
  if [ -z "$target" ] || [ $# -eq 0 ]; then
    echo "Usage: onchange <file-or-dir> <command...>" >&2
    return 1
  fi

  echo "Watching $target… (Ctrl-C to stop)"
  while inotifywait -q -e close_write,create,move,delete "$target"; do
    "$@"
  done
}

##! [nav] mkcd
##! Desc: Create a directory (including parents) and cd into it.
##! Usage:
##!   mkcd <dir>
##! Examples:
##!   mkcd src/new/module
##! Notes:
##!   - Uses `mkdir -p` so it is safe if the directory already exists.
mkcd() {
  [ -z "$1" ] && { echo "Usage: mkcd <dir>"; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}

##! [git] cproj
##! Desc: Change directory to the root of the current Git project.
##! Usage:
##!   cproj
##! Examples:
##!   # from anywhere in a Git repo tree:
##!   cproj
##! Notes:
##!   - Falls back to `.` if not inside a Git repository.
cproj() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="."
  cd "$root" || return
}

##! [nav] cdf
##! Desc: Change directory to the directory containing a file.
##! Usage:
##!   cdf <file-or-dir>
##! Examples:
##!   cdf /var/log/syslog
##!   cdf src/main.cpp
##! Notes:
##!   - Works with both files and directories.
##!   - Resolves the directory path via `dirname` and `pwd`.
cdf() {
  [ -z "$1" ] && { echo "Usage: cdf <file>"; return 1; }
  local target="$1"
  [ -f "$target" ] || [ -d "$target" ] || { echo "No such file: $target"; return 1; }
  cd "$(cd "$(dirname "$target")" && pwd)" || return
}


##! [archive] extract
##! Desc: Extract archives with automatic format detection.
##! Usage:
##!   extract <archive>
##! Examples:
##!   extract foo.tar.gz
##!   extract bar.zip
##! Notes:
##!   - Supports common formats: .tar.gz, .tar.bz2, .tar.xz, .zip, .rar, .7z, etc.
##!   - Requires `unrar` or `7z` for those respective formats.
extract() {
  if [ -z "$1" ]; then
    echo "Usage: extract <archive>" >&2
    return 1
  fi

  if [ ! -f "$1" ]; then
    echo "extract: '$1' is not a file" >&2
    return 1
  fi

  case "$1" in
    *.tar.bz2)   tar xjf "$1"   ;;
    *.tar.gz)    tar xzf "$1"   ;;
    *.tar.xz)    tar xJf "$1"   ;;
    *.tar)       tar xf "$1"    ;;
    *.tbz2)      tar xjf "$1"   ;;
    *.tgz)       tar xzf "$1"   ;;
    *.zip)       unzip "$1"     ;;
    *.rar)       unrar x "$1"   ;;
    *.7z)        7z x "$1"      ;;
    *)           echo "extract: unsupported file type '$1'" >&2; return 1 ;;
  esac
}

if command -v fzf >/dev/null 2>&1; then
##! [search] f
##! Desc: Fuzzy-find a file and print its path (requires fzf).
##! Usage:
##!   f                 # search from current directory
##!   f <dir>           # search from <dir>
##! Examples:
##!   vim "$(f)"
##! Notes:
##!   - Uses `find` piped into `fzf`.
f() {
find "${1:-.}" -type f 2>/dev/null | fzf
}

##! [search] fh
##! Desc: Fuzzy-search shell history and execute the chosen command.
##! Usage:
##!   fh
##! Notes:
##!   - Displays history via `history`, filters with `fzf`, then runs the selection.
##!   - Shows the chosen command before executing.
fh() {
local cmd
cmd=$(history | fzf +s +m | sed 's/ *[0-9]* *//')
[ -n "$cmd" ] && printf '%s\n' "$cmd" && eval "$cmd"
}
fi

##! [system] topcpu
##! Desc: Show processes sorted by CPU usage (top 10–15).
##! Usage:
##!   topcpu
##! Notes:
##!   - Uses `ps -eo ... --sort=-%cpu | head`.
topcpu() {
  ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n 15
}

##! [system] topmem
##! Desc: Show processes sorted by memory usage (top 10–15).
##! Usage:
##!   topmem
##! Notes:
##!   - Uses `ps -eo ... --sort=-%mem | head`.
topmem() {
  ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 15
}
