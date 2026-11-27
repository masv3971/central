# central

Central repository for SUNET agent skills. Skills live in [.github/skills](.github/skills) and are distributed to other repos as versioned release bundles.

## Install into a repo

The script is attached to every release, so fetch it once and run it:

```bash
gh release download --repo masv3971/central --pattern central-sync.sh && chmod +x central-sync.sh
./central-sync.sh                                         # latest release, all skills
./central-sync.sh -v v1.2.0 sunet-prreview                # pinned version, selected skills
```

Skills are copied to `.github/skills/` (override with `-d`). The installed version is recorded in `.github/skills/.skills-version`. Synced skills are overwritten on every run, so change them here, not in the consuming repo.

Each run also copies [.central](.central) into the repo's `.central/` and appends `-include .central/common.mk` to the repo's `Makefile` if it is missing. Edit the shared files here, not in the consuming repo. Skills stay in `.github/skills/` so agents find them. The include sits at the end of the `Makefile`, so redefining a shared target locally makes the shared recipe win with an "overriding recipe" warning. Use different target names.

Requires `gh` or `curl`. Set `SKILLS_REPO=owner/repo` to use a fork.

## Add or change a skill

1. Create `.github/skills/<name>/SKILL.md`. The frontmatter `name` must match the directory name.
2. Open a PR. CI validates all skills.

## Release

```bash
make release                # patch bump of the latest vX.Y.Z tag
make release BUMP=minor     # or major
```

This tags the next version and pushes it (needs a clean tree on `main`; `FORCE=true` overrides). The pipeline builds `central-<version>.tar.gz` and its `.sha256` and publishes them as a GitHub release. Use semver; renaming or removing a skill is a major bump.

Both release targets first prepend a section to `CHANGELOG.md` and commit it.

### Projects that ship Docker images

```bash
make docker-release                  # release, plus build and push images
make docker-release BUMP=minor DOCKER_EXTRA_TAG=   # no extra tag
```

`docker-release` does the same as `release`, and also calls the project's own `docker-build`, `docker-push` and `docker-tag` targets. Define them in the project's `Makefile`; each is called with `VERSION=<tag>` and `_RELEASE_MODE=1`, and `docker-tag` also gets `NEWTAG=`. Images are built before the git tag is created and pushed after it. The new tag is then also pushed as `:dev` (`DOCKER_EXTRA_TAG`, empty to skip). If the image push fails after the tag is out, the error names the command to finish it.

Build locally with `scripts/build-bundle.sh <version>` (output in `dist/`).
