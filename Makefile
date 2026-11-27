.PHONY: bundle

bundle:
	@test -n "$(VERSION)" || { echo "usage: make bundle VERSION=v0.1.0"; exit 1; }
	scripts/build-bundle.sh $(VERSION)

include .central/common.mk
