. ~/.shared_shell_env_safe

if [ -x /opt/homebrew/bin/brew ] && [ -f "$(/opt/homebrew/bin/brew --prefix)/etc/bash_completion" ]; then
    . "$(/opt/homebrew/bin/brew --prefix)/etc/bash_completion"
fi
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
. "$HOME/.cargo/env"

