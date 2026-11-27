BUMP         ?= patch
FORCE        ?=
SKILLS_REPO  ?= masv3971/central
# Extra image tag docker-release moves to the new build (empty to skip).
DOCKER_EXTRA_TAG ?= dev

.PHONY: release docker-release _release get_release-tag gh-install gh-auth central-sync-install

# Downloads the latest central-sync.sh release asset to .central/central-sync.sh.
central-sync-install:
	@mkdir -p .central
	@if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then \
		gh release download --repo "$(SKILLS_REPO)" --pattern central-sync.sh --dir .central --clobber; \
	else \
		curl -fsSL -o .central/central-sync.sh "https://github.com/$(SKILLS_REPO)/releases/latest/download/central-sync.sh"; \
	fi
	@chmod +x .central/central-sync.sh
	@echo "installed .central/central-sync.sh"

gh-install:
	@if ! command -v gh >/dev/null 2>&1; then \
		sudo mkdir -p -m 755 /etc/apt/keyrings && \
		curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
			sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
		sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
			sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
		sudo apt-get update && \
		sudo apt-get install -y gh; \
	else \
		echo "gh already installed: $$(gh --version | head -1)"; \
	fi

gh-auth: gh-install
	@if gh auth status >/dev/null 2>&1; then \
		gh auth status; \
	else \
		gh auth login; \
	fi

get_release-tag: ## Show the latest vX.Y.Z tag
	@t=$$(git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -n1); echo "$${t:-v0.0.0}"

# Tags the next vX.Y.Z and pushes it.
release: ## Tag and push the next release (BUMP=major|minor|patch)
	@$(MAKE) --no-print-directory _release

# Same as release, plus Docker images. The project defines docker-build, docker-push
# and docker-tag; each gets VERSION=<tag> (docker-tag also NEWTAG=) and _RELEASE_MODE=1.
docker-release: ## Like release, and build and push Docker images (BUMP=major|minor|patch)
	@$(MAKE) --no-print-directory _release RELEASE_DOCKER=1

_release:
	@set -e; \
	echo "$(BUMP)" | grep -qE '^(major|minor|patch)$$' || \
		{ echo "Error: BUMP must be major, minor, or patch (got: $(BUMP))"; exit 1; }; \
	if [ "$(FORCE)" != "true" ]; then \
		[ "$$(git rev-parse --abbrev-ref HEAD)" = main ] || \
			{ echo "Error: not on main (use FORCE=true to override)"; exit 1; }; \
		git diff --quiet HEAD || \
			{ echo "Error: working tree is dirty (use FORCE=true to override)"; exit 1; }; \
		[ -z "$$(git ls-files --others --exclude-standard -- CHANGELOG.md)" ] || \
			{ echo "Error: CHANGELOG.md is untracked (use FORCE=true to override)"; exit 1; }; \
	fi; \
	if [ -n "$(RELEASE_DOCKER)" ]; then \
		for t in docker-build docker-push $(if $(DOCKER_EXTRA_TAG),docker-tag); do \
			$(MAKE) --no-print-directory -n $$t VERSION=v0.0.0 NEWTAG=$(DOCKER_EXTRA_TAG) _RELEASE_MODE=1 >/dev/null 2>&1 || \
				{ echo "Error: docker-release needs a $$t target in this Makefile"; exit 1; }; \
		done; \
	fi; \
	LATEST=$$(git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -n1); \
	LATEST=$${LATEST:-v0.0.0}; \
	if [ "$$LATEST" != v0.0.0 ] && [ -z "$$(git ls-remote --tags origin "refs/tags/$$LATEST")" ]; then \
		echo "Error: $$LATEST is not on origin, likely a failed release. Push it, or remove it with 'git tag -d $$LATEST' and undo its changelog commit."; exit 1; \
	fi; \
	CURRENT=$${LATEST#v}; \
	MAJOR=$$(echo "$$CURRENT" | cut -d. -f1); \
	MINOR=$$(echo "$$CURRENT" | cut -d. -f2); \
	PATCH=$$(echo "$$CURRENT" | cut -d. -f3); \
	case "$(BUMP)" in \
		major) MAJOR=$$((MAJOR + 1)); MINOR=0; PATCH=0 ;; \
		minor) MINOR=$$((MINOR + 1)); PATCH=0 ;; \
		patch) PATCH=$$((PATCH + 1)) ;; \
	esac; \
	NEW_TAG="v$$MAJOR.$$MINOR.$$PATCH"; \
	echo ""; \
	echo "$$LATEST -> $$NEW_TAG"; \
	echo ""; \
	if git rev-parse "$$NEW_TAG" >/dev/null 2>&1; then \
		echo "Error: tag $$NEW_TAG already exists"; exit 1; \
	fi; \
	bash .central/release-changelog.sh "$$NEW_TAG" "$$LATEST"; \
	git add CHANGELOG.md; \
	git diff --cached --quiet -- CHANGELOG.md || git commit -m "chore: changelog for $$NEW_TAG" -- CHANGELOG.md; \
	if [ -n "$(RELEASE_DOCKER)" ]; then \
		echo "Building Docker images for $$NEW_TAG before creating the git tag..."; \
		$(MAKE) docker-build VERSION=$$NEW_TAG _RELEASE_MODE=1; \
	fi; \
	git tag -a "$$NEW_TAG" -m "Release $$NEW_TAG"; \
	git push --atomic origin HEAD "$$NEW_TAG"; \
	echo ""; \
	echo "==> $$NEW_TAG pushed"; \
	echo ""; \
	if [ -n "$(RELEASE_DOCKER)" ]; then \
		echo "Pushing Docker images for $$NEW_TAG..."; \
		P="make docker-push VERSION=$$NEW_TAG _RELEASE_MODE=1"; \
		T="make docker-tag VERSION=$$NEW_TAG NEWTAG=$(DOCKER_EXTRA_TAG) _RELEASE_MODE=1"; \
		X="make docker-push VERSION=$(DOCKER_EXTRA_TAG) _RELEASE_MODE=1"; \
		fail() { echo "Error: $$NEW_TAG is tagged and pushed, but $$1 failed. Run the rest by hand:"; shift; for c in "$$@"; do echo "  $$c"; done; exit 1; }; \
		$(MAKE) docker-push VERSION=$$NEW_TAG _RELEASE_MODE=1 || fail "docker-push of $$NEW_TAG" "$$P" $(if $(DOCKER_EXTRA_TAG),"$$T" "$$X"); \
		if [ -n "$(DOCKER_EXTRA_TAG)" ]; then \
			$(MAKE) docker-tag VERSION=$$NEW_TAG NEWTAG=$(DOCKER_EXTRA_TAG) _RELEASE_MODE=1 || fail "docker-tag $(DOCKER_EXTRA_TAG)" "$$T" "$$X"; \
			$(MAKE) docker-push VERSION=$(DOCKER_EXTRA_TAG) _RELEASE_MODE=1 || fail "docker-push of $(DOCKER_EXTRA_TAG)" "$$X"; \
		fi; \
		echo ""; \
		echo "==> Docker images pushed for $$NEW_TAG$(if $(DOCKER_EXTRA_TAG), (:$(DOCKER_EXTRA_TAG)))"; \
		echo ""; \
	fi
