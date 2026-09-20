#!/bin/bash
# Native macOS script. Dry run by default; use --delete to remove matches.
set -u

DELETE=0
YES=0
if [[ "${1:-}" == "--delete" ]]; then DELETE=1; shift; fi
if [[ "${1:-}" == "--yes" ]]; then YES=1; shift; fi
if [[ $# -gt 0 ]]; then
  ROOTS=("$@")
else
  # -x prevents crossing mount points, so add each mounted volume explicitly.
  ROOTS=("/")
  for volume in /Volumes/*; do
    [[ -d "$volume" ]] && ROOTS+=("$volume")
  done
fi

repos=(bootcoding-cicd academic-prep-backend academic-admin-backend email-service academic-admin-frontend academic-prep-frontend bootcoding-site havet-website havet-website-green aceint-analytics-backend aceint-analytics-frontend hireskill-frontend hireskill-site student2developer bootcoding-media data-scripts client-agent job-api)

normalize() {
  local u="$1"
  u="${u#\"}"; u="${u%\"}"; u="${u#\'}"; u="${u%\'}"
  u="${u#http://}"; u="${u#https://}"; u="${u#ssh://}"; u="${u#git@}"
  u="${u/github.com:/github.com/}"; u="${u%%\?*}"; u="${u%%#*}"; u="${u%/}"; u="${u%.git}"
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

matching_remote() {
  local config="$1" line in_remote=0 value normalized remote_section
  remote_section='^[[:space:]]*\[remote[[:space:]]+"[^"]+"\][[:space:]]*$'
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ $remote_section ]]; then in_remote=1; continue; fi
    if [[ "$line" =~ ^[[:space:]]*\[ ]]; then in_remote=0; continue; fi
    if (( in_remote )) && [[ "$line" =~ ^[[:space:]]*url[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"; normalized=$(normalize "$value")
      for repo in "${repos[@]}"; do
        [[ "$normalized" == "github.com/devgpt0/$repo" ]] && { printf '%s' "$normalized"; return 0; }
      done
    fi
  done < "$config"
  return 1
}

found_dirs=()
found_remotes=()
echo 'Scanning local file systems for matching Git repositories...'
for root in "${ROOTS[@]}"; do
  while IFS= read -r gitmeta; do
    [[ -z "$gitmeta" ]] && continue
    if [[ -d "$gitmeta" ]]; then config="$gitmeta/config"; else config="$(dirname "$gitmeta")/config"; fi
    [[ -f "$config" ]] || continue
    remote=$(matching_remote "$config") || continue
    repo_dir=$(dirname "$gitmeta")
    already=0
    for existing in "${found_dirs[@]}"; do [[ "$existing" == "$repo_dir" ]] && already=1; done
    if (( ! already )); then found_dirs+=("$repo_dir"); found_remotes+=("$remote"); fi
  done < <(find -x "$root" \( -type d -name .git -o -type f -name .git \) -print 2>/dev/null)
done

if (( ${#found_dirs[@]} == 0 )); then echo 'No matching repositories were found.'; exit 0; fi
echo; echo "Matching repository folders (${#found_dirs[@]}):"
for i in "${!found_dirs[@]}"; do echo "[${found_remotes[$i]}] ${found_dirs[$i]}"; done
if (( ! DELETE )); then echo; echo 'Dry run only. Re-run with --delete to remove these folders.'; exit 0; fi
if (( ! YES )); then read -r -p 'Type DELETE to permanently remove these folders: ' answer; [[ "$answer" == DELETE ]] || { echo 'Cancelled.'; exit 0; }; fi
for dir in "${found_dirs[@]}"; do
  if rm -rf -- "$dir"; then echo "Removed: $dir"; else echo "Could not remove: $dir" >&2; fi
done
