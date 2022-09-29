# make config
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash -euo pipefail
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
GIT_SHA_SHORT = $(shell git rev-parse --short=10 HEAD)

## Check production dependencies
check-prod:
	./dev/check-required-prod-dependencies.sh

## Check development dependencies
check-dev:
	./dev/check-required-dev-dependencies.sh

.PHONY: docs
## Build the docs -- output location is docs/book
docs: check-dev
	./docs/mdbook-shim.sh build docs

## Build and live-reload the docs
docs-watch: check-dev
	./docs/mdbook-shim.sh watch --open docs

## Get repo back to a clean slate
clean:
	rm -rf docs/book
	rm -rf docs/bin
	rm -rf outputs
	rm -rf nginx.conf


# https://gist.github.com/prwhite/8168133#gistcomment-2278355
# https://gist.github.com/prwhite/8168133#gistcomment-2749866
.PHONY: help
help:
	@printf "Usage\n\n";

	@awk '{ \
			if ($$0 ~ /^.PHONY: [a-zA-Z\-_0-9]+$$/) { \
				helpCommand = substr($$0, index($$0, ":") + 2); \
				if (helpMessage) { \
					printf "\033[36m%-30s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^[a-zA-Z\-_0-9.]+:/) { \
				helpCommand = substr($$0, 0, index($$0, ":")); \
				if (helpMessage) { \
					printf "\033[36m%-30s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^##/) { \
				if (helpMessage) { \
					helpMessage = helpMessage"\n                               "substr($$0, 3); \
				} else { \
					helpMessage = substr($$0, 3); \
				} \
			} else { \
				if (helpMessage) { \
					print "\n                     "helpMessage"\n" \
				} \
				helpMessage = ""; \
			} \
		}' \
		$(MAKEFILE_LIST)
