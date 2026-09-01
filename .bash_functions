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

##! [git] gotoremote
##! Desc: Add another user's fork as a remote and check out one of their branches.
##! Usage:
##!   gotoremote [-w|--worktree|--worktree=<path>] <user>:<branch>
##!   gotoremote [-w] <user> <branch>
##!   gotoremote [-w] <https://host/user/repo/tree/branch>
##! Examples:
##!   gotoremote tmchow:fix/3304-reduce-sum-static-ref-type
##!   gotoremote -w tmchow:fix/3304-reduce-sum-static-ref-type
##!   gotoremote --worktree=../review tmchow:fix/3304-reduce-sum-static-ref-type
##!   gotoremote https://github.com/tmchow/math/tree/fix/3304-reduce-sum-static-ref-type
##! Options:
##!   -w, --worktree          Check the branch out in a new git worktree and cd there.
##!   --worktree=<path>       Same, but at an explicit path.
##! Notes:
##!   - Must be run inside a Git repo. The fork URL is `origin`'s URL with the
##!     owner swapped, so the protocol (ssh, https, ...) and host are preserved.
##!   - Adds remote <user> if missing, fetches <branch>, then checks out a local
##!     branch of the same name tracking <user>/<branch>.
##!   - Re-running fast-forwards an existing local branch; it never force-updates
##!     or discards local work.
##!   - The default worktree path is ../<repo>-<user>-<branch> beside the repo root.
gotoremote() {
  local spec="" use_worktree="" wt_path="" wt_root="" wt_slug=""
  local user="" branch="" rest="" proto=""
  local origin_url="" base="" repo="" new_url="" remote_url="" upstream=""

  if [ $# -eq 0 ]; then
    echo "gotoremote: usage: gotoremote [-w] <user>:<branch>" >&2
    return 1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        cat <<'EOF'
gotoremote - add another user's fork as a remote and check out their branch.
Usage:
  gotoremote [-w|--worktree|--worktree=<path>] <user>:<branch>
  gotoremote [-w] <user> <branch>
  gotoremote [-w] <https://host/user/repo/tree/branch>
Options:
  -w, --worktree        Check the branch out in a new git worktree and cd there.
  --worktree=<path>     Same, but at an explicit path.
  -h, --help            Show this help and exit.
Examples:
  gotoremote tmchow:fix/3304-reduce-sum-static-ref-type
  gotoremote -w tmchow:fix/3304-reduce-sum-static-ref-type
EOF
        return 0
        ;;
      -w|--worktree)
        use_worktree=1
        shift
        ;;
      --worktree=*)
        use_worktree=1
        wt_path="${1#--worktree=}"
        if [ -z "$wt_path" ]; then
          echo "gotoremote: --worktree= needs a path" >&2
          return 1
        fi
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "gotoremote: unknown option: $1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  spec="$1"
  if [ -z "$spec" ]; then
    echo "gotoremote: usage: gotoremote [-w] <user>:<branch>" >&2
    return 1
  fi

  case "$spec" in
    http://*|https://*|ssh://*)
      rest="${spec%/}"
      rest="${rest#*://}"
      rest="${rest#*/}"          # drop host, leaving <user>/<repo>/tree/<branch>
      user="${rest%%/*}"
      branch="${rest#*/tree/}"
      if [ -z "$user" ] || [ "$branch" = "$rest" ]; then
        echo "gotoremote: cannot parse <user>/<repo>/tree/<branch> out of: $spec" >&2
        return 1
      fi
      ;;
    *:*)
      user="${spec%%:*}"
      branch="${spec#*:}"
      ;;
    *)
      user="$spec"
      branch="$2"
      ;;
  esac

  if [ -z "$user" ] || [ -z "$branch" ]; then
    echo "gotoremote: usage: gotoremote <user>:<branch>" >&2
    return 1
  fi

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "gotoremote: not inside a Git repository" >&2
    return 1
  }

  origin_url=$(git config --get remote.origin.url 2>/dev/null)
  if [ -z "$origin_url" ]; then
    rest=$(git remote | head -n 1)
    [ -n "$rest" ] && origin_url=$(git config --get "remote.$rest.url" 2>/dev/null)
  fi
  if [ -z "$origin_url" ]; then
    echo "gotoremote: no remotes configured, cannot infer the repository URL" >&2
    return 1
  fi

  # Swap the owner segment of origin's URL, keeping its protocol so that the
  # existing ssh keys / credential helper keep working.
  base="${origin_url%/}"
  base="${base%.git}"
  repo="${base##*/}"
  rest="${base%/*}"              # everything up to and including the owner
  if [ -z "$repo" ] || [ "$rest" = "$base" ]; then
    echo "gotoremote: cannot infer <owner>/<repo> from origin URL: $origin_url" >&2
    return 1
  fi
  if [ "${rest##*/}" = "$rest" ]; then
    proto="${rest%%:*}:"         # scp-like git@host:owner
  else
    proto="${rest%/*}/"          # https://host/owner, ssh://host/owner, /path/owner
  fi
  new_url="${proto}${user}/${repo}.git"

  remote_url=$(git config --get "remote.$user.url" 2>/dev/null)
  if [ -n "$remote_url" ]; then
    if [ "${remote_url%.git}" != "${new_url%.git}" ]; then
      echo "gotoremote: remote '$user' already points at $remote_url (leaving as-is)" >&2
    fi
  else
    git remote add "$user" "$new_url" || return 1
    remote_url="$new_url"
    echo "gotoremote: added remote $user -> $new_url"
  fi

  git fetch "$user" "+refs/heads/${branch}:refs/remotes/${user}/${branch}" || return 1

  if [ -n "$use_worktree" ]; then
    wt_root=$(git rev-parse --show-toplevel) || return 1
    if [ -z "$wt_path" ]; then
      wt_slug=$(printf '%s' "$branch" | tr '/' '-')
      wt_path="${wt_root%/*}/${repo}-${user}-${wt_slug}"
    fi
    if [ -e "$wt_path" ]; then
      echo "gotoremote: $wt_path already exists, entering it without touching it" >&2
    elif git show-ref --verify --quiet "refs/heads/${branch}"; then
      git worktree add "$wt_path" "$branch" || return 1
    else
      git worktree add --track -b "$branch" "$wt_path" "${user}/${branch}" || return 1
    fi
    cd "$wt_path" || return 1
    echo "gotoremote: worktree $(pwd) on '$branch' from ${user} (${remote_url})"
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    git checkout "$branch" || return 1
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)
    if [ "$upstream" = "${user}/${branch}" ]; then
      git merge --ff-only "${user}/${branch}" || {
        echo "gotoremote: local '$branch' has diverged from ${user}/${branch}; left untouched" >&2
        return 1
      }
    else
      echo "gotoremote: local branch '$branch' already exists (upstream: ${upstream:-none})" >&2
      echo "gotoremote: leaving it untouched; to take theirs: git reset --hard ${user}/${branch}" >&2
      return 1
    fi
  else
    git checkout -b "$branch" --track "${user}/${branch}" || return 1
  fi

  echo "gotoremote: on '$branch' from ${user} (${remote_url})"
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
