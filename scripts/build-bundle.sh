#!/usr/bin/env bash
# Validate skills and build dist/central-<version>.tar.gz plus a .sha256 file.
# Usage: build-bundle.sh <version>
set -euo pipefail

version="${1:?usage: build-bundle.sh <version>}"
root="$(git rev-parse --show-toplevel)"
src="$root/.github/skills"
out="$root/dist"
name="central-$version"

for dir in "$src"/*/; do
  skill="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || { echo "$skill: missing SKILL.md" >&2; exit 1; }
  declared="$(sed -n '1,/^---$/{s/^name:[[:space:]]*//p}' "$dir/SKILL.md" | head -n1)"
  [ "$declared" = "$skill" ] || { echo "$skill: frontmatter name '$declared' does not match directory" >&2; exit 1; }
done

rm -rf "$out"
mkdir -p "$out/stage/skills"
cp -r "$src"/. "$out/stage/skills/"
cp -r "$root/.central" "$out/stage/central"
echo "$version" > "$out/stage/VERSION"

tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='2000-01-01 UTC' \
  -C "$out/stage" -czf "$out/$name.tar.gz" VERSION skills central
rm -rf "$out/stage"

(cd "$out" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")
echo "built $out/$name.tar.gz"
