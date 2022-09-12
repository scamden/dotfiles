. ~/.shared_shell_env_safe

zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash
fpath=(~/.zsh $fpath)

autoload -Uz compinit && compinit

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
