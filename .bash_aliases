# Color setup block (no doc block needed)
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    ##! [search] grep
    ##! Desc: Colorized grep.
    ##! Usage: grep [PATTERN] [FILES...]
    alias grep='grep --color=auto'
    ##! [search] fgrep
    ##! Desc: Colorized fixed-string grep.
    ##! Usage: fgrep [STRING] [FILES...]
    alias fgrep='fgrep --color=auto'
    ##! [search] egrep
    ##! Desc: Colorized extended-regex grep.
    ##! Usage: egrep [ERE] [FILES...]
    alias egrep='egrep --color=auto'
    ##! [fs] ls
    ##! Desc: Colorized ls (GNU).
    ##! Usage: ls [OPTIONS] [FILES...]
    alias ls='ls --color=auto'
fi

##! [fs] ll
##! Desc: Long listing with hidden info & type suffixes.
##! Usage: ll [PATH]
alias ll='ls -alF'

##! [fs] la
##! Desc: List all (including dotfiles) without `.` and `..`.
##! Usage: la [PATH]
alias la='ls -A'

##! [fs] l
##! Desc: Columnar short listing.
##! Usage: l [PATH]
alias l='ls -CF'

##! [util] alert
##! Desc: Desktop notification for the last command’s success/failure.
##! Usage: long_command ; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

##! [util] copy_last
##! Desc: Copy the last entered command to the clipboard.
##! Usage: copy_last
alias copy_last='fc -ln -1| xsel --clipboard'

##! [git] subup
##! Desc: Update git repository remote submodules.
##! Usage: subup
alias subup="git submodule update --remote"

##! [git] gs
##! Desc: Show concise Git status including branch and short file list.
##! Usage:
##!   gs
##! Notes:
##!   - Equivalent to `git status -sb`.
alias gs='git status -sb'

##! [git] gd
##! Desc: Show Git diff for the current repository.
##! Usage:
##!   gd
##!   gd <args>  # additional options passed through to `git diff`
alias gd='git diff'

##! [git] gl
##! Desc: Pretty Git log with graph and decorated refs.
##! Usage:
##!   gl
##! Notes:
##!   - Equivalent to `git log --oneline --graph --decorate --all`.
alias gl='git log --oneline --graph --decorate --all'

##! [git] gco
##! Desc: Git checkout shorthand.
##! Usage:
##!   gco <branch-or-commit>
##! Examples:
##!   gco main
##!   gco -  # checkout previous branch
alias gco='git checkout'

##! [git] gb
##! Desc: List local Git branches.
##! Usage:
##!   gb
alias gb='git branch'

##! [git] gcm
##! Desc: Commit staged changes with a message.
##! Usage:
##!   gcm "your commit message"
alias gcm='git commit -m'

##! [util] please
##! Desc: Rerun the last command with sudo.
##! Usage:
##!   <run a command that needs root>
##!   please
##! Notes:
##!   - Uses `history -p !!` to expand the previous command safely.
##!   - Prints and executes the last command prefixed with `sudo`.
alias please='sudo $(history -p !!)'

##! [shell] reload
##! Desc: Reload your Bash configuration in the current shell.
##! Usage:
##!   reload
##! Notes:
##!   - Runs `source ~/.bashrc`.
alias reload='source ~/.bashrc'
