# zsh reads this for every shell, including non-interactive scripts.
# Keep it limited to cheap, deterministic environment setup.
export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"

path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  "$HOME/.local/share/mise/shims"
  "$HOME/.local/bin"
  "$HOME/bin"
  $path
)
typeset -U path PATH
