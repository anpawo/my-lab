# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:$HOME/.docker/bin"
# End of Docker Desktop section.

# Settings
set fish_greeting
set fish_prompt_pwd_dir_length 0

# Key Binding
# bind \cH backward-kill-word # Only on linux
# bind \cH backward-word

# Alias
alias fishdir="c ~/.config/fish/"

alias l="ll"
alias "l."="ll -a"
alias cl="clear && printf '\e[3J'"
alias cp="pbcopy"
alias md="mkdir"
alias max="yabai -m window --toggle zoom-fullscreen"
alias gdb="echo 'lldb for mac'"
alias p="python"
alias cld="claude"
alias grep="grep -E --color=always"
alias cdd="cd .."

alias m="make -j"
alias f="make fclean"
alias d="make debug -j"
alias r="make run"

alias g.="git add ."
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias g="git status"
alias gl="git log --oneline"

# Github Access
ssh-add --apple-use-keychain ~/.ssh/github.self 2>/dev/null

# VCPKG
set -x VCPKG_ROOT ~/.local/share/vcpkg

# Local Binaries
fish_add_path ~/.local/bin

# Github SSH Key Agent
if not pgrep -u $USER ssh-agent >/dev/null
    eval (ssh-agent -c)
end
ssh-add -l | grep github.self >/dev/null

# Prevent macOS AppKit / Input Method Kit log (For QT)
set -x NSUnbufferedIO YES

# In case an app crashes and there's a mac popup
# defaults write com.apple.CrashReporter DialogType none

# PyEnv instead of HomeBrew for Python
set -x PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/shims $PYENV_ROOT/bin


# Ghostty was launched from a Claude session and inherited CLAUDE_CODE_CHILD_SESSION:
# every tab opened since calls itself a child session, and Claude Code doesn't keep the
# transcript of a child session — hence the "New session" tiles with no name or history in Fleet.
set -x CLAUDE_CODE_FORCE_SESSION_PERSISTENCE 1

# Go to home
cd
