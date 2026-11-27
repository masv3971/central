#!/usr/bin/env bash
# Install skills from a central release bundle into the current repo.
# Usage: central-sync.sh [-v version] [-d dest] [skill ...]   (default: latest, all skills)
set -euo pipefail

SLUG="${SKILLS_REPO:-masv3971/central}"
VERSION="latest"
DEST=".github/skills"

while getopts "v:d:" opt; do
  case "$opt" in
    v) VERSION="$OPTARG" ;;
    d) DEST="$OPTARG" ;;
    *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  tag_arg=()
  [ "$VERSION" = "latest" ] || tag_arg=("$VERSION")
  gh release download "${tag_arg[@]}" --repo "$SLUG" --dir "$tmp" --pattern 'central-*.tar.gz*' --pattern 'coding-skills-*.tar.gz*'
else
  if [ "$VERSION" = "latest" ]; then
    VERSION="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$SLUG/releases/latest")"
    VERSION="${VERSION##*/}"
  fi
  # Releases before the rename ship coding-skills-*, so fall back to that name.
  for prefix in central coding-skills; do
    base="https://github.com/$SLUG/releases/download/$VERSION/$prefix-$VERSION.tar.gz"
    if curl -fsSL -o "$tmp/$prefix-$VERSION.tar.gz" "$base"; then
      curl -fsSL -o "$tmp/$prefix-$VERSION.tar.gz.sha256" "$base.sha256"
      break
    fi
    rm -f "$tmp/$prefix-$VERSION.tar.gz"
  done
fi

bundle=$(compgen -G "$tmp/central-*.tar.gz" | head -n1 || true)
[ -n "$bundle" ] || bundle=$(compgen -G "$tmp/coding-skills-*.tar.gz" | head -n1 || true)
[ -n "$bundle" ] || { echo "no release bundle found for $VERSION in $SLUG" >&2; exit 1; }
(cd "$tmp" && sha256sum --check --quiet "$(basename "$bundle").sha256")

mkdir -p "$tmp/x"
tar -xzf "$bundle" -C "$tmp/x"
src="$tmp/x/skills"

if [ "$#" -gt 0 ]; then
  skills=("$@")
else
  mapfile -t skills < <(find "$src" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi

mkdir -p "$DEST"
for skill in "${skills[@]}"; do
  [ -d "$src/$skill" ] || { echo "unknown skill: $skill" >&2; exit 1; }
  rm -rf "${DEST:?}/$skill"
  cp -r "$src/$skill" "$DEST/$skill"
  echo "synced $skill"
done

if [ -d "$tmp/x/central" ]; then
  mkdir -p .central
  cp -r "$tmp/x/central/." .central/
  include_line='-include .central/common.mk'
  mk=Makefile
  for f in GNUmakefile makefile Makefile; do
    [ -f "$f" ] && { mk=$f; break; }
  done
  if [ ! -f "$mk" ] || ! grep -qxF -e "$include_line" "$mk"; then
    printf '\n%s\n' "$include_line" >> "$mk"
  fi
  echo "synced .central"
fi

cp "$tmp/x/VERSION" "$DEST/.skills-version"
echo "central $(cat "$DEST/.skills-version")"
