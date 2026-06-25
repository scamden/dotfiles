# Worktree cockpit helpers for iTerm2.

WORKON_HOME="${WORKON_HOME:-$HOME/.config/workon}"
WORKON_ITERM_DYNAMIC_PROFILE_PATH="${WORKON_ITERM_DYNAMIC_PROFILE_PATH:-$HOME/Library/Application Support/iTerm2/DynamicProfiles/workon-worktree.json}"
WORKON_CACHE_HOME="${WORKON_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/workon}"
WORKON_ITERM_PROFILE_REGISTRY="${WORKON_ITERM_PROFILE_REGISTRY:-$WORKON_CACHE_HOME/iterm-worktrees.tsv}"
WORKON_ITERM_PARENT_PROFILE="${WORKON_ITERM_PARENT_PROFILE:-default}"

typeset -ga WORKON_PALETTE=(
  "2b2238" "17313a" "30251f" "1e3326"
  "342331" "243047" "3a2f17" "26342f"
  "2f2841" "193640" "3b2426" "22351f"
)

workon__repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

workon__repo_name() {
  local root remote name
  root="${1:-$(workon__repo_root)}"
  [ -n "$root" ] || return 1
  remote="$(git -C "$root" remote get-url origin 2>/dev/null)"
  if [ -n "$remote" ]; then
    name="$(basename "$remote")"
    printf '%s\n' "${name%.git}"
    return
  fi
  basename "$root"
}

workon__branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null \
    || git rev-parse --short HEAD 2>/dev/null
}

workon__branch_exists() {
  [ -n "$1" ] || return 1
  git show-ref --verify --quiet "refs/heads/$1"
}

workon__branch_slug() {
  printf '%s' "$1" \
    | tr '/[:space:]' '---' \
    | tr -cd '[:alnum:]._-'
}

workon__worktree_for_branch() {
  [ -n "$1" ] || return 1
  git worktree list --porcelain 2>/dev/null \
    | awk -v branch="refs/heads/$1" '
      /^worktree / {
        path = substr($0, 10)
        next
      }
      /^branch / && substr($0, 8) == branch {
        print path
        exit
      }
    '
}

workon__git_exclude_path() {
  git rev-parse --git-path info/exclude 2>/dev/null
}

workon__ensure_worktrees_ignored() {
  local exclude_path
  exclude_path="$(workon__git_exclude_path)" || return 1
  [ -n "$exclude_path" ] || return 1
  mkdir -p "${exclude_path:h}"
  touch "$exclude_path"
  if ! grep -qxF ".worktrees/" "$exclude_path"; then
    printf '\n.worktrees/\n' >> "$exclude_path"
  fi
}

workon__select_branch() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
    return
  fi

  if typeset -f choose_machete_branch >/dev/null; then
    choose_machete_branch
    return
  fi

  git branch --sort=-committerdate \
    | sed 's/^[* ]*//' \
    | fzf --header "Choose branch"
}

workon__resolve_worktree() {
  local branch root existing slug target
  branch="$1"
  root="$(workon__repo_root)" || {
    echo "workon: not in a git repository" >&2
    return 1
  }

  if ! workon__branch_exists "$branch"; then
    echo "workon: no local branch named '$branch'" >&2
    return 1
  fi

  existing="$(workon__worktree_for_branch "$branch")"
  if [ -n "$existing" ]; then
    printf '%s\n' "$existing"
    return
  fi

  slug="$(workon__branch_slug "$branch")"
  target="$root/.worktrees/$slug"
  printf '%s\n' "$target"
}

workon__ensure_worktree() {
  local branch target
  branch="$1"
  target="$(workon__resolve_worktree "$branch")" || return 1

  if [ -d "$target" ]; then
    printf '%s\n' "$target"
    return
  fi

  workon__ensure_worktrees_ignored || return 1
  git worktree add "$target" "$branch" >/dev/null || return 1
  printf '%s\n' "$target"
}

workon__layout_rows() {
  local repo="$1"
  case "$repo" in
    platform)
      print -r -- "git|."
      print -r -- "dev server|."
      print -r -- "storybook|packages/ui"
      print -r -- "ui scratch|packages/ui"
      print -r -- "tsapi scratch|packages/tsapi"
      ;;
    personal-agent-work)
      print -r -- "git|."
      print -r -- "premise dev|apps/premise"
      print -r -- "presence coach dev|apps/presence-coach"
      print -r -- "premise scratch|apps/premise"
      print -r -- "presence scratch|apps/presence-coach"
      ;;
    *)
      print -r -- "git/scratch|."
      print -r -- "dev server|."
      ;;
  esac
}

workon__hash_index() {
  local identity="$1" count="$2" sum
  sum="$(printf '%s' "$identity" | cksum | awk '{print $1}')"
  echo $(( (sum % count) + 1 ))
}

workon__color_for_identity() {
  local identity="$1" index
  index="$(workon__hash_index "$identity" "${#WORKON_PALETTE[@]}")"
  printf '%s\n' "${WORKON_PALETTE[$index]}"
}

workon__json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "$value"
}

workon__hex_component() {
  local hex="$1" start="$2"
  awk -v component="$((16#${hex[$start,$((start + 1))]}))" 'BEGIN { printf "%.6f", component / 255 }'
}

workon__color_json() {
  local color="$1" indent="$2"
  print -r -- "$indent\"Color Space\": \"sRGB\","
  print -r -- "$indent\"Red Component\": $(workon__hex_component "$color" 1),"
  print -r -- "$indent\"Green Component\": $(workon__hex_component "$color" 3),"
  print -r -- "$indent\"Blue Component\": $(workon__hex_component "$color" 5)"
}

workon__profile_guid() {
  local identity="$1" hash
  hash="$(printf '%s' "$identity" | shasum -a 1 | awk '{print $1}')"
  printf '%s-%s-%s-%s-%s\n' "${hash[1,8]}" "${hash[9,12]}" "${hash[13,16]}" "${hash[17,20]}" "${hash[21,32]}"
}

workon__worktree_profile_rows() {
  local repo_root="$1"
  git -C "$repo_root" worktree list --porcelain 2>/dev/null \
    | awk '
      function emit() {
        if (path == "") return
        display = branch
        sub(/^refs\/heads\//, "", display)
        if (display == "") display = "detached-" substr(head, 1, 8)
        print path "\t" display
      }
      /^worktree / {
        emit()
        path = substr($0, 10)
        branch = ""
        head = ""
        next
      }
      /^HEAD / { head = substr($0, 6); next }
      /^branch / { branch = substr($0, 8); next }
      END { emit() }
    '
}

workon__remember_iterm_profiles() {
  local repo_root="$1" repo="$2" registry_dir tmp
  registry_dir="${WORKON_ITERM_PROFILE_REGISTRY:h}"
  mkdir -p "$registry_dir" || return 1
  tmp="$(mktemp "$registry_dir/workon-registry.XXXXXX")" || return 1

  {
    [ ! -f "$WORKON_ITERM_PROFILE_REGISTRY" ] || cat "$WORKON_ITERM_PROFILE_REGISTRY"
    workon__worktree_profile_rows "$repo_root" | while IFS=$'\t' read -r worktree_path branch; do
      print -r -- "$repo"$'\t'"$branch"$'\t'"$worktree_path"
    done
  } | awk -F '\t' 'NF == 3 { rows[$3] = $0 } END { for (path in rows) print rows[path] }' \
    | sort > "$tmp" || return 1

  mv "$tmp" "$WORKON_ITERM_PROFILE_REGISTRY"
}

workon__print_iterm_profile() {
  local repo="$1" branch="$2" worktree_path="$3" identity color tab_color guid
  identity="$repo:$branch"
  color="$(workon__color_for_identity "$identity")"
  tab_color="$color"
  guid="$(workon__profile_guid "$identity:$worktree_path")"

  print -r -- "    {"
  print -r -- "      \"Name\": $(workon__json_string "workon: $repo | $branch"),"
  print -r -- "      \"Guid\": $(workon__json_string "$guid"),"
  print -r -- "      \"Dynamic Profile Parent Name\": $(workon__json_string "$WORKON_ITERM_PARENT_PROFILE"),"
  print -r -- "      \"Bound Hosts\": ["
  print -r -- "        $(workon__json_string "$worktree_path"),"
  print -r -- "        $(workon__json_string "$worktree_path/*")"
  print -r -- "      ],"
  print -r -- "      \"Background Color\": {"
  workon__color_json "$color" "        "
  print -r -- "      },"
  print -r -- "      \"Badge Color\": {"
  print -r -- "        \"Color Space\": \"sRGB\","
  print -r -- "        \"Alpha Component\": 0.34,"
  print -r -- "        \"Red Component\": 0.615686,"
  print -r -- "        \"Green Component\": 0.717647,"
  print -r -- "        \"Blue Component\": 0.784314"
  print -r -- "      },"
  print -r -- "      \"Use Tab Color\": true,"
  print -r -- "      \"Tab Color\": {"
  workon__color_json "$tab_color" "        "
  print -r -- "      }"
  print -r -- "    }"
}

workon__write_iterm_dynamic_profiles() {
  local profile_dir tmp_base tmp first repo branch worktree_path
  profile_dir="${WORKON_ITERM_DYNAMIC_PROFILE_PATH:h}"
  mkdir -p "$profile_dir" || return 1
  tmp_base="${TMPDIR:-/tmp}"
  tmp_base="${tmp_base%/}"
  tmp="$(mktemp "$tmp_base/workon-profiles.XXXXXX")" || return 1

  {
    print -r -- "{"
    print -r -- "  \"Profiles\": ["
    first=1
    if [ -f "$WORKON_ITERM_PROFILE_REGISTRY" ]; then
      while IFS=$'\t' read -r repo branch worktree_path; do
        [ -n "$repo" ] && [ -n "$branch" ] && [ -n "$worktree_path" ] || continue
        if [ "$first" -eq 0 ]; then
          print -r -- ","
        fi
        workon__print_iterm_profile "$repo" "$branch" "$worktree_path"
        first=0
      done < "$WORKON_ITERM_PROFILE_REGISTRY"
    fi
    print -r -- ""
    print -r -- "  ]"
    print -r -- "}"
  } > "$tmp" || return 1

  mv "$tmp" "$WORKON_ITERM_DYNAMIC_PROFILE_PATH"
}

workon__sync_iterm_profiles() {
  local repo_root="$1" repo="$2"
  workon__remember_iterm_profiles "$repo_root" "$repo" || return 1
  workon__write_iterm_dynamic_profiles
}

workon__mise_source_is_trusted() {
  local source_root="$1" trust_status
  [ -n "$source_root" ] || return 1
  if ! typeset -f mise >/dev/null && ! (( $+commands[mise] )); then
    return 1
  fi

  trust_status="$(mise trust --show -C "$source_root" 2>/dev/null)" || return 1
  [[ "$trust_status" == *": trusted"* ]]
}

workon__mise_trusted_config_paths() {
  local source_root="$1" worktree_root="$2"
  workon__mise_source_is_trusted "$source_root" || return 0
  printf '%s:%s\n' "$source_root" "$worktree_root"
}

workon__set_iterm_badge() {
  local badge encoded
  badge="$1"
  encoded="$(printf '%s' "$badge" | base64 | tr -d '\n')"
  printf '\033]1337;SetBadgeFormat=%s\a' "$encoded"
}

workon_refresh_visuals() {
  [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || return 0

  local actual_root actual_repo actual_branch rel badge
  actual_root="$(workon__repo_root)" || {
    workon__set_iterm_badge "no git repo"
    return 0
  }

  actual_repo="$(workon__repo_name "$actual_root")"
  actual_branch="$(workon__branch)"
  rel="${PWD#$actual_root}"
  rel="${rel#/}"
  [ -n "$rel" ] || rel="."

  if [ -n "${WORKON_ROOT:-}" ] && [ "$actual_root" != "$WORKON_ROOT" ]; then
    badge="MISMATCH | $actual_repo | $actual_branch"
  else
    badge="$actual_repo | $actual_branch"
  fi

  workon__set_iterm_badge "$badge"
}

workon__write_pane_script() {
  local activation_dir="$1" index="$2" dir="$3" repo="$4" branch="$5" role="$6" root="$7" trusted_config_paths="${8:-}"
  local script quoted_dir quoted_root quoted_repo quoted_branch quoted_role quoted_trusted_config_paths
  script="$activation_dir/pane-$index.zsh"
  quoted_dir="${(qq)dir}"
  quoted_root="${(qq)root}"
  quoted_repo="${(qq)repo}"
  quoted_branch="${(qq)branch}"
  quoted_role="${(qq)role}"
  quoted_trusted_config_paths="${(qq)trusted_config_paths}"

  {
    print -r -- "# Generated by workon for one local iTerm pane."
    if [ -n "$trusted_config_paths" ]; then
      print -r -- "export MISE_TRUSTED_CONFIG_PATHS=$quoted_trusted_config_paths"
    fi
    print -r -- "export WORKON_ROOT=$quoted_root"
    print -r -- "export WORKON_REPO=$quoted_repo"
    print -r -- "export WORKON_BRANCH=$quoted_branch"
    print -r -- "export WORKON_ROLE=$quoted_role"
    print -r -- "cd $quoted_dir || exit"
    print -r -- "unset WORKON_HOOKS_INSTALLED"
    print -r -- "exec zsh -l"
  } > "$script" || return 1

  chmod 600 "$script" || return 1
  printf '%s\n' "$script"
}

workon__shell_command() {
  local script="$1"
  printf 'source %s' "${(qq)script}"
}

workon__osascript_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

workon__open_iterm() {
  local root="$1" branch="$2" repo="$3" trusted_config_paths="${4:-}" tmp_base activation_dir row index role rel dir script command quoted_command
  local -a rows commands roles

  tmp_base="${TMPDIR:-/tmp}"
  tmp_base="${tmp_base%/}"
  activation_dir="$(umask 077 && mktemp -d "$tmp_base/workon.XXXXXX")" || return 1

  while IFS= read -r row; do
    rows+=("$row")
  done < <(workon__layout_rows "$repo")

  index=1
  for row in "${rows[@]}"; do
    role="${row%%|*}"
    rel="${row#*|}"
    if [ "$rel" = "." ]; then
      dir="$root"
    else
      dir="$root/$rel"
    fi
    script="$(workon__write_pane_script "$activation_dir" "$index" "$dir" "$repo" "$branch" "$role" "$root" "$trusted_config_paths")" || return 1
    commands+=("$(workon__shell_command "$script")")
    roles+=("$role")
    index=$((index + 1))
  done

  {
    print -r -- 'tell application "iTerm2"'
    print -r -- '  «event Itrmnwwn»'
    print -r -- '  delay 0.2'
    print -r -- '  set newWindow to «property Crwn»'
    print -r -- '  set baseSession to «property Wcsn» of newWindow'
    print -r -- "  set name of baseSession to \"$(workon__osascript_quote "${roles[1]}")\""
    print -r -- "  «event Itrmsntx» baseSession given «class Text»:\"$(workon__osascript_quote "${commands[1]}")\", «class Wtnl»:true"

    if [ "${#commands[@]}" -eq 5 ]; then
      print -r -- '  set bottomLeftSession to «event Itrmsvdp» baseSession'
      print -r -- "  set name of bottomLeftSession to \"$(workon__osascript_quote "${roles[2]}")\""
      print -r -- "  «event Itrmsntx» bottomLeftSession given «class Text»:\"$(workon__osascript_quote "${commands[2]}")\", «class Wtnl»:true"

      print -r -- '  set topRightSession to «event Itrmshdp» baseSession'
      print -r -- "  set name of topRightSession to \"$(workon__osascript_quote "${roles[4]}")\""
      print -r -- "  «event Itrmsntx» topRightSession given «class Text»:\"$(workon__osascript_quote "${commands[4]}")\", «class Wtnl»:true"

      print -r -- '  set bottomMiddleSession to «event Itrmshdp» bottomLeftSession'
      print -r -- "  set name of bottomMiddleSession to \"$(workon__osascript_quote "${roles[3]}")\""
      print -r -- "  «event Itrmsntx» bottomMiddleSession given «class Text»:\"$(workon__osascript_quote "${commands[3]}")\", «class Wtnl»:true"

      print -r -- '  set bottomRightSession to «event Itrmshdp» bottomMiddleSession'
      print -r -- "  set name of bottomRightSession to \"$(workon__osascript_quote "${roles[5]}")\""
      print -r -- "  «event Itrmsntx» bottomRightSession given «class Text»:\"$(workon__osascript_quote "${commands[5]}")\", «class Wtnl»:true"
    else
      index=2
      while [ "$index" -le "${#commands[@]}" ]; do
        quoted_command="$(workon__osascript_quote "${commands[$index]}")"
        if (( index % 2 == 0 )); then
          print -r -- '  set newSession to «event Itrmsvdp» baseSession'
        else
          print -r -- '  set newSession to «event Itrmshdp» baseSession'
        fi
        print -r -- "  set name of newSession to \"$(workon__osascript_quote "${roles[$index]}")\""
        print -r -- "  «event Itrmsntx» newSession given «class Text»:\"$quoted_command\", «class Wtnl»:true"
        index=$((index + 1))
      done
    fi

    print -r -- '  select newWindow'
    print -r -- 'end tell'
  } | osascript
}

workon_plan() {
  local branch root repo worktree
  branch="$(workon__select_branch "${1:-}")"
  [ -n "$branch" ] || return 1
  worktree="$(workon__resolve_worktree "$branch")" || return 1
  root="$(workon__repo_root)" || return 1
  repo="$(workon__repo_name "$root")"

  echo "branch: $branch"
  echo "repo: $repo"
  echo "worktree: $worktree"
  echo "layout:"
  workon__layout_rows "$repo" | sed 's/^/  - /'
}

workon() {
  local dry_run branch root repo worktree trusted_config_paths
  if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ]; then
    dry_run=1
    shift
  fi

  branch="$(workon__select_branch "${1:-}")"
  [ -n "$branch" ] || return 1

  if [ -n "$dry_run" ]; then
    workon_plan "$branch"
    return
  fi

  root="$(workon__repo_root)" || return 1
  repo="$(workon__repo_name "$root")"
  worktree="$(workon__ensure_worktree "$branch")" || return 1
  workon__sync_iterm_profiles "$root" "$repo" || return 1
  trusted_config_paths="$(workon__mise_trusted_config_paths "$root" "$worktree")"
  workon__open_iterm "$worktree" "$branch" "$repo" "$trusted_config_paths"
}

co() {
  local branch worktree current_root checkout_status
  branch="$(workon__select_branch "${1:-}")"
  [ -n "$branch" ] || return 1

  worktree="$(workon__worktree_for_branch "$branch")"
  current_root="$(workon__repo_root)"

  if [ -n "$worktree" ] && [ "$worktree" != "$current_root" ]; then
    cd "$worktree" || return
    echo "co: cd'd to worktree for '$branch': $worktree"
    echo "co: skipped git checkout; only this terminal pane changed directories."
    print -s "cd \"$worktree\""
    if [ -n "${WORKON_ROOT:-}" ]; then
      workon_refresh_visuals
    fi
    return
  fi

  git checkout "$branch"
  checkout_status=$?
  if [ "$checkout_status" -eq 0 ]; then
    print -s "git checkout \"$branch\""
    if [ -n "${WORKON_ROOT:-}" ]; then
      workon_refresh_visuals
    fi
  fi
  return "$checkout_status"
}

wt() {
  git worktree list --porcelain \
    | awk '
      /^worktree / { path = substr($0, 10); branch = ""; head = ""; next }
      /^HEAD / { head = substr($0, 6); next }
      /^branch / {
        branch = substr($0, 8)
        sub(/^refs\/heads\//, "", branch)
        printf "%-36s %s\n", branch, path
        next
      }
      /^$/ && path != "" && branch == "" {
        printf "%-36s %s\n", "(detached " substr(head, 1, 8) ")", path
      }
    '
}

whereami() {
  local actual_root actual_repo actual_branch rel
  actual_root="$(workon__repo_root)" || {
    echo "actual: no git repo at $PWD"
    return 1
  }
  actual_repo="$(workon__repo_name "$actual_root")"
  actual_branch="$(workon__branch)"
  rel="${PWD#$actual_root}"
  rel="${rel#/}"
  [ -n "$rel" ] || rel="."

  echo "actual repo: $actual_repo"
  echo "actual branch: $actual_branch"
  echo "actual worktree: $actual_root"
  echo "actual path: $rel"

  if [ -n "${WORKON_ROOT:-}" ]; then
    echo "intended repo: ${WORKON_REPO:-?}"
    echo "intended branch: ${WORKON_BRANCH:-?}"
    echo "intended worktree: $WORKON_ROOT"
    if [ "$actual_root" = "$WORKON_ROOT" ]; then
      echo "status: inside intended worktree"
    else
      echo "status: MISMATCH"
    fi
  fi
}

if [ -n "${ZSH_VERSION:-}" ] && [ -n "${WORKON_ROOT:-}" ] && [ -z "${WORKON_HOOKS_INSTALLED:-}" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null
  if typeset -f add-zsh-hook >/dev/null; then
    add-zsh-hook chpwd workon_refresh_visuals
    add-zsh-hook precmd workon_refresh_visuals
    typeset -g WORKON_HOOKS_INSTALLED=1
    workon_refresh_visuals
  fi
fi
