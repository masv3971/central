BUMP  ?= patch
FORCE ?=

.PHONY: bundle release gh-install gh-auth

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

bundle:
	@test -n "$(VERSION)" || { echo "usage: make bundle VERSION=v0.1.0"; exit 1; }
	scripts/build-bundle.sh $(VERSION)

# Tags the next vX.Y.Z and pushes it; the release workflow builds and publishes the bundle.
release:
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
	echo "$$LATEST -> $$NEW_TAG"; \
	git tag -a "$$NEW_TAG" -m "Release $$NEW_TAG"; \
	git push origin "$$NEW_TAG"; \
	echo "==> $$NEW_TAG pushed; the release workflow publishes the bundle"
