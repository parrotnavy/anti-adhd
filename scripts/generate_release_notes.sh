#!/usr/bin/env bash
set -euo pipefail
IFS=$' \n\t'

umask 022
export LC_ALL=C
export LANG=C

usage() {
  cat >&2 <<'EOF'
Usage: scripts/generate_release_notes.sh [--version X.Y.Z] [--from <ref>] [--to <ref>]

Generates deterministic Markdown release notes from git commit history.

Options:
  --version X.Y.Z   Optional; used only for the title heading.
  --from <ref>      Optional; start ref (exclusive). If omitted, auto-detect previous v* tag.
  --to <ref>        Optional; end ref (inclusive). Defaults to HEAD.
  -h, --help        Show this help.

Output:
  # <title>
  ## Changes
  - <subject> (<shortsha>)
EOF
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_git_repo() {
  command -v git >/dev/null 2>&1 || fail "git not found"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git work tree"
}

rev_to_commit() {
  local ref
  ref="$1"
  git rev-parse --verify "${ref}^{commit}" 2>/dev/null
}

detect_previous_v_tag() {
  local to_commit search_commit candidate
  to_commit="$1"
  search_commit="$to_commit"

  if git tag --points-at "$to_commit" --list 'v*' | grep -q .; then
    if git rev-parse --verify "${to_commit}^" >/dev/null 2>&1; then
      search_commit="${to_commit}^"
    else
      search_commit=""
    fi
  fi

  if [[ -z "$search_commit" ]]; then
    return 1
  fi

  candidate="$(git describe --tags --abbrev=0 --match 'v*' "$search_commit" 2>/dev/null || true)"
  [[ -n "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

main() {
  local version from_ref to_ref to_commit previous_tag title
  version=""
  from_ref=""
  to_ref="HEAD"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        [[ $# -ge 2 ]] || fail "--version requires a value"
        version="$2"
        shift 2
        ;;
      --from)
        [[ $# -ge 2 ]] || fail "--from requires a ref"
        from_ref="$2"
        shift 2
        ;;
      --to)
        [[ $# -ge 2 ]] || fail "--to requires a ref"
        to_ref="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done

  require_git_repo

  to_commit="$(rev_to_commit "$to_ref" || true)"
  [[ -n "$to_commit" ]] || fail "Unable to resolve --to ref '$to_ref' to a commit"

  if [[ -n "$from_ref" ]]; then
    local from_commit
    from_commit="$(rev_to_commit "$from_ref" || true)"
    [[ -n "$from_commit" ]] || fail "Unable to resolve --from ref '$from_ref' to a commit"
  else
    previous_tag="$(detect_previous_v_tag "$to_commit" || true)"
    if [[ -n "$previous_tag" ]]; then
      from_ref="$previous_tag"
    fi
  fi

  title="Release Notes"
  if [[ -n "$version" ]]; then
    title="v$version"
  fi

  printf '# %s\n\n' "$title"
  printf '## Changes\n'

  if [[ -n "$from_ref" ]]; then
    git -c log.showSignature=false --no-pager log \
      --no-merges \
      --format='%s (%h)' \
      "${from_ref}..${to_commit}" \
      | while IFS= read -r line; do
          [[ -n "$line" ]] || continue
          printf -- '- %s\n' "$line"
        done
  else
    git -c log.showSignature=false --no-pager log \
      --no-merges \
      --format='%s (%h)' \
      "$to_commit" \
      | while IFS= read -r line; do
          [[ -n "$line" ]] || continue
          printf -- '- %s\n' "$line"
        done
  fi
}

main "$@"
