#!/usr/bin/env bash
# Refresh releases/stars and preserve the historical clone-based download totals.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRASSETS_DIR="${MIRASSETS_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)}"
for dependency in gh git jq; do
  command -v "$dependency" >/dev/null || { echo "Error: $dependency is required" >&2; exit 1; }
done
[ -d "$MIRASSETS_DIR/images" ] || { echo "Error: missing images directory" >&2; exit 1; }
# Refuse to include someone else's staged or uncommitted work.
[ -z "$(git -C "$MIRASSETS_DIR" status --porcelain)" ] || { echo "Error: mirassets checkout must be clean" >&2; exit 1; }
git -C "$MIRASSETS_DIR" pull --ff-only
update_value() {
  sed -i -E "s#(class=\"value\">)[^<]*(</text>)#\1$2\2#" "$1"
}
for entry in 'hossbit/local-ai-server|localai' 'hossbit/comai-linux-assistant|comai'; do
  IFS='|' read -r repo prefix <<< "$entry"
  # Fetch and validate everything before changing this project's badges.
  release="$(gh api "repos/$repo/releases/latest" --jq '.tag_name')"
  [[ "$release" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Error: unsupported release tag for $repo" >&2; exit 1; }
  stars="$(gh api "repos/$repo" --jq '.stargazers_count')"
  [[ "$stars" =~ ^[0-9]+$ ]] || { echo "Error: invalid counts for $repo" >&2; exit 1; }
  release_file="$MIRASSETS_DIR/images/$prefix-badge-release.svg"
  stars_file="$MIRASSETS_DIR/images/$prefix-badge-stars.svg"
  download_file="$MIRASSETS_DIR/images/$prefix-badge-download.svg"
  update_value "$release_file" "$release"
  sed -i -E "s#(aria-label=\"Latest release )[^\"]*(\")#\1$release\2#; s#(<title>Latest release: )[^<]*(</title>)#\1$release\2#" "$release_file"
  update_value "$stars_file" "$stars"
  sed -i -E "s#(aria-label=\")[0-9]+( GitHub stars\")#\1$stars\2#; s#(<title>GitHub stars: )[0-9]+(</title>)#\1$stars\2#" "$stars_file"
  total_file="$MIRASSETS_DIR/images/$prefix-download-total.txt"
  last_run_file="$MIRASSETS_DIR/images/$prefix-download-last-run.txt"
  downloads="$(cat "$total_file")"
  last_run=0
  [ ! -f "$last_run_file" ] || last_run="$(cat "$last_run_file")"
  [[ "$downloads" =~ ^[0-9]+$ && "$last_run" =~ ^[0-9]+$ ]] || { echo "Error: invalid saved clone counters for $repo" >&2; exit 1; }
  now="$(date +%s)"
  # GitHub exposes a rolling 14-day clone count. Do not add overlapping windows.
  if (( now - last_run >= 14 * 86400 )); then
    if [ -n "${GH_STATS_TOKEN:-}" ]; then
      clones="$(GH_TOKEN="$GH_STATS_TOKEN" gh api "repos/$repo/traffic/clones" --jq '.count' 2>/dev/null)" || clones=""
    else
      clones="$(gh api "repos/$repo/traffic/clones" --jq '.count' 2>/dev/null)" || clones=""
    fi
    if [[ "$clones" =~ ^[0-9]+$ ]]; then
      downloads=$((10#$downloads + 10#$clones))
      printf '%s\n' "$downloads" > "$total_file"
      printf '%s\n' "$now" > "$last_run_file"
    else
      echo "$repo: clone statistics unavailable; keeping the saved total"
    fi
  fi
  update_value "$download_file" "$downloads"
  sed -i -E "s#aria-label=\"[^\"]*downloads\"#aria-label=\"$downloads downloads\"#; s#<title>[^<]*</title>#<title>Downloads: $downloads</title>#; s#class=\"label\">[^<]*<#class=\"label\">Download<#" "$download_file"
  echo "$repo: $release, $stars stars, $downloads recorded clone downloads"

done
git -C "$MIRASSETS_DIR" add -- images
if git -C "$MIRASSETS_DIR" diff --cached --quiet; then echo 'Badges are current.'; exit 0; fi
git -C "$MIRASSETS_DIR" commit -m "Refresh project badges"
git -C "$MIRASSETS_DIR" push
