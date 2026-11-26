# coding-skills

Central repository for SUNET agent skills. Skills live in [.github/skills](.github/skills) and are distributed to other repos as versioned release bundles.

## Install into a repo

The script is attached to every release, so fetch it once and run it:

```bash
gh release download --repo masv3971/coding-skills --pattern sync-skills.sh && chmod +x sync-skills.sh
./sync-skills.sh                                         # latest release, all skills
./sync-skills.sh -v v1.2.0 sunet-prreview                # pinned version, selected skills
```

Skills are copied to `.github/skills/` (override with `-d`). The installed version is recorded in `.github/skills/.skills-version`. Synced skills are overwritten on every run, so change them here, not in the consuming repo.

Requires `gh` or `curl`. Set `SKILLS_REPO=owner/repo` to use a fork.

## Add or change a skill

1. Create `.github/skills/<name>/SKILL.md`. The frontmatter `name` must match the directory name.
2. Open a PR. CI validates all skills.

## Release

```bash
make release                # patch bump of the latest vX.Y.Z tag
make release BUMP=minor     # or major
```

This tags the next version and pushes it (needs a clean tree on `main`; `FORCE=true` overrides). The pipeline builds `coding-skills-<version>.tar.gz` and its `.sha256` and publishes them as a GitHub release. Use semver; renaming or removing a skill is a major bump.

Build locally with `scripts/build-bundle.sh <version>` (output in `dist/`).
