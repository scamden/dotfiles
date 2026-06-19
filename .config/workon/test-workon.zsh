#!/usr/bin/env zsh
set -euo pipefail

source "${0:h}/workon.zsh"

[[ -z "${WORKON_HOOKS_INSTALLED:-}" ]] || {
  echo "expected sourcing workon outside a cockpit not to install visual hooks" >&2
  exit 1
}

hook_check="$(
  WORKON_ROOT=/tmp/root zsh -f -c 'source "$1"; [[ -n "${WORKON_HOOKS_INSTALLED:-}" ]] && print installed' zsh "${0:h}/workon.zsh"
)"
[[ "$hook_check" == "installed" ]] || {
  echo "expected sourcing workon inside a cockpit to install visual hooks" >&2
  exit 1
}

tmpdir="$(mktemp -d /private/tmp/workon-test.XXXXXX)"
cd "$tmpdir"
git init --quiet
git config user.email test@example.com
git config user.name Test
git config commit.gpgsign false
printf initial > file.txt
git add file.txt
git commit --quiet -m initial
git branch feature-one
git branch feature/path

expected="$tmpdir/.worktrees/feature-one"
planned="$(workon__resolve_worktree feature-one)"
[[ "$planned" == "$expected" ]] || {
  echo "expected planned worktree $expected, got $planned" >&2
  exit 1
}

created="$(workon__ensure_worktree feature-one)"
[[ "$created" == "$expected" ]] || {
  echo "expected created worktree $expected, got $created" >&2
  exit 1
}

[[ -d "$expected" ]] || {
  echo "expected worktree directory to exist" >&2
  exit 1
}

grep -qxF ".worktrees/" "$(git rev-parse --git-path info/exclude)" || {
  echo "expected .worktrees/ to be added to git exclude" >&2
  exit 1
}

discovered="$(workon__worktree_for_branch feature-one)"
[[ "$discovered" == "$expected" ]] || {
  echo "expected discovered worktree $expected, got $discovered" >&2
  exit 1
}

if workon__resolve_worktree missing 2>/dev/null; then
  echo "missing branch unexpectedly resolved" >&2
  exit 1
fi

path_expected="$tmpdir/.worktrees/feature-path"
path_created="$(workon__ensure_worktree feature/path)"
[[ "$path_created" == "$path_expected" ]] || {
  echo "expected slash branch worktree $path_expected, got $path_created" >&2
  exit 1
}

cd "$tmpdir"
co feature/path >/tmp/workon-co-output.txt
[[ "$PWD" == "$path_expected" ]] || {
  echo "expected co to cd to existing worktree, got $PWD" >&2
  exit 1
}
grep -q "skipped git checkout" /tmp/workon-co-output.txt || {
  echo "expected co to say it skipped checkout" >&2
  exit 1
}

cd "$tmpdir"
git branch plain
co plain >/tmp/workon-co-checkout-output.txt
[[ "$(git symbolic-ref --quiet --short HEAD)" == "plain" ]] || {
  echo "expected co to checkout local branch when no other worktree exists" >&2
  exit 1
}

layout="$(workon__layout_rows personal-agent-work | wc -l | tr -d ' ')"
[[ "$layout" == "5" ]] || {
  echo "expected personal-agent-work layout to have 5 panes, got $layout" >&2
  exit 1
}

platform_layout="$(workon__layout_rows platform)"
echo "$platform_layout" | grep -qxF "dev server|." || {
  echo "expected platform dev server to start at repo root" >&2
  exit 1
}
echo "$platform_layout" | grep -qxF "ui scratch|packages/ui" || {
  echo "expected platform ui scratch to start in packages/ui" >&2
  exit 1
}

rm -f /tmp/workon-injection-marker
mkdir -p "/tmp/some path"
activation_dir="$(mktemp -d /private/tmp/workon-activate-test.XXXXXX)"
script="$(workon__write_pane_script "$activation_dir" 1 "/tmp/some path" "repo" "feature/quote;touch /tmp/workon-injection-marker" "git" "/tmp/root")"
sed '$d' "$script" > /tmp/workon-pane-no-exec.zsh
WORKON_HOME="${0:h}" TERM_PROGRAM= zsh -f /tmp/workon-pane-no-exec.zsh
[[ ! -e /tmp/workon-injection-marker ]] || {
  echo "expected shell command quoting to prevent command injection" >&2
  exit 1
}
command="$(workon__shell_command "$script")"
[[ "$command" == source\ *pane-1.zsh* ]] || {
  echo "expected AppleScript command to source a short pane bootstrap script" >&2
  exit 1
}

mise() {
  if [[ "$*" == "trust --show -C /trusted source" ]]; then
    print "/trusted source: trusted"
    return 0
  fi
  print "$4: untrusted"
}
trusted_paths="$(workon__mise_trusted_config_paths "/trusted source" "/trusted worktree")"
[[ "$trusted_paths" == "/trusted source:/trusted worktree" ]] || {
  echo "expected trusted source repo to produce scoped trusted config paths, got $trusted_paths" >&2
  exit 1
}
untrusted_paths="$(workon__mise_trusted_config_paths "/untrusted source" "/untrusted worktree")"
[[ -z "$untrusted_paths" ]] || {
  echo "expected untrusted source repo not to produce scoped trusted config paths" >&2
  exit 1
}
trusted_script="$(workon__write_pane_script "$activation_dir" 2 "/tmp/some path" "repo" "branch" "git" "/tmp/root" "$trusted_paths")"
grep -q "export MISE_TRUSTED_CONFIG_PATHS=" "$trusted_script" || {
  echo "expected pane script to export scoped mise trusted paths when provided" >&2
  exit 1
}
trusted_line="$(grep -n "export MISE_TRUSTED_CONFIG_PATHS=" "$trusted_script" | cut -d: -f1)"
cd_line="$(grep -n "^cd " "$trusted_script" | cut -d: -f1)"
(( trusted_line < cd_line )) || {
  echo "expected pane script to export mise trust before cd triggers mise hooks" >&2
  exit 1
}
grep -q "unset WORKON_HOOKS_INSTALLED" "$trusted_script" || {
  echo "expected pane script to let the final login shell reinstall visual hooks" >&2
  exit 1
}
if grep -q "workon_refresh_visuals\\|workon__schedule_visual_refresh\\|source .*workon.zsh" "$trusted_script"; then
  echo "expected pane script to leave visual refresh to the final login shell" >&2
  exit 1
fi
unfunction mise

osascript() { cat > /tmp/workon-generated.applescript }
workon__open_iterm "$tmpdir" "feature/path" "personal-agent-work"
grep -q "«event Itrmnwwn»" /tmp/workon-generated.applescript || {
  echo "expected generated AppleScript to use raw iTerm create-window event" >&2
  exit 1
}
grep -q "set newWindow to «property Crwn»" /tmp/workon-generated.applescript || {
  echo "expected generated AppleScript to use current-window fallback after creation" >&2
  exit 1
}
grep -q "«event Itrmsvdp»" /tmp/workon-generated.applescript || {
  echo "expected generated AppleScript to use raw iTerm vertical split event" >&2
  exit 1
}
grep -q "«event Itrmshdp»" /tmp/workon-generated.applescript || {
  echo "expected generated AppleScript to use raw iTerm horizontal split event" >&2
  exit 1
}
grep -q "«event Itrmsntx»" /tmp/workon-generated.applescript || {
  echo "expected generated AppleScript to use raw iTerm write event" >&2
  exit 1
}
if grep -q $'\033' /tmp/workon-generated.applescript || grep -q $'\007' /tmp/workon-generated.applescript; then
  echo "expected generated AppleScript not to contain raw terminal control bytes" >&2
  exit 1
fi
if grep -q "WORKON_ROOT\\|printf '\\\\\\\\033" /tmp/workon-generated.applescript; then
  echo "expected generated AppleScript to source short pane scripts instead of embedding setup commands" >&2
  exit 1
fi
grep -q "source .*pane-1.zsh" /tmp/workon-generated.applescript || {
  echo "expected generated AppleScript to source a pane bootstrap script" >&2
  exit 1
}
grep -q "set bottomLeftSession to «event Itrmsvdp» baseSession" /tmp/workon-generated.applescript || {
  echo "expected five-pane layout to create a bottom row from the base session" >&2
  exit 1
}
grep -q "set topRightSession to «event Itrmshdp» baseSession" /tmp/workon-generated.applescript || {
  echo "expected five-pane layout to split the top row into two panes" >&2
  exit 1
}
grep -q "set bottomMiddleSession to «event Itrmshdp» bottomLeftSession" /tmp/workon-generated.applescript || {
  echo "expected five-pane layout to split the bottom row into three panes" >&2
  exit 1
}
grep -q 'set name of topRightSession to "premise scratch"' /tmp/workon-generated.applescript || {
  echo "expected Personal Workbench top-right pane to be a scratch pane" >&2
  exit 1
}
grep -q 'set name of bottomLeftSession to "premise dev"' /tmp/workon-generated.applescript || {
  echo "expected Personal Workbench bottom-left pane to be a dev pane" >&2
  exit 1
}
grep -q 'set name of bottomMiddleSession to "presence coach dev"' /tmp/workon-generated.applescript || {
  echo "expected Personal Workbench bottom-middle pane to be the other dev pane" >&2
  exit 1
}
workon__open_iterm "$tmpdir" "feature/path" "platform"
grep -q 'set name of topRightSession to "ui scratch"' /tmp/workon-generated.applescript || {
  echo "expected platform top-right pane to be UI scratch" >&2
  exit 1
}
grep -q 'set name of bottomLeftSession to "dev server"' /tmp/workon-generated.applescript || {
  echo "expected platform bottom-left pane to be dev server" >&2
  exit 1
}
grep -q 'set name of bottomMiddleSession to "storybook"' /tmp/workon-generated.applescript || {
  echo "expected platform bottom-middle pane to be Storybook" >&2
  exit 1
}
grep -q 'set name of bottomRightSession to "tsapi scratch"' /tmp/workon-generated.applescript || {
  echo "expected platform bottom-right pane to be TS API scratch" >&2
  exit 1
}
if grep -q "«class Nwcm»" /tmp/workon-generated.applescript; then
  echo "expected generated AppleScript not to pass setup commands as session command parameters" >&2
  exit 1
fi
osacompile -o /tmp/workon-generated.scpt /tmp/workon-generated.applescript

print "workon tests passed"
