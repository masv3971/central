BUMP         ?= patch
FORCE        ?=
SKILLS_REPO  ?= masv3971/central

.PHONY: release get_release-tag gh-install gh-auth central-sync-install

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
	@git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -n1 || echo "v0.0.0"

# Tags the next vX.Y.Z and pushes it.
release: ## Tag and push the next release (BUMP=major|minor|patch)
	@set -e; \
	echo "$(BUMP)" | grep -qE '^(major|minor|patch)$$' || \
		{ echo "Error: BUMP must be major, minor, or patch (got: $(BUMP))"; exit 1; }; \
	if [ "$(FORCE)" != "true" ]; then \
		[ "$$(git rev-parse --abbrev-ref HEAD)" = main ] || \
			{ echo "Error: not on main (use FORCE=true to override)"; exit 1; }; \
		git diff --quiet HEAD || \
			{ echo "Error: working tree is dirty (use FORCE=true to override)"; exit 1; }; \
	fi; \
	LATEST=$$(git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -n1); \
	LATEST=$${LATEST:-v0.0.0}; \
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
	git tag -a "$$NEW_TAG" -m "Release $$NEW_TAG"; \
	git push --atomic origin HEAD "$$NEW_TAG"; \
	echo ""; \
	echo "==> $$NEW_TAG pushed"; \
	echo ""
