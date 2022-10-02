#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT=$(cd "${CURRENT_DIRECTORY}/.." && pwd)

# shellcheck source=../scripts/helpers/logging.sh
source "${PROJECT_ROOT}/scripts/helpers/logging.sh"

MDBOOK_PLANTUML_VERSION=0.8.0

if ! [[ -f "${CURRENT_DIRECTORY}/bin/mdbook-plantuml" ]] ||
    ! "${CURRENT_DIRECTORY}"/bin/mdbook-plantuml --version | grep "${MDBOOK_PLANTUML_VERSION}"; then
    log_info "Need to install or update the mdbook-plantuml dependency"
    cargo install --root "${CURRENT_DIRECTORY}" "mdbook-plantuml@${MDBOOK_PLANTUML_VERSION}"
else
    log_debug "mdbook and dependencies look good"
fi

# keep this up to date with the value in the book.toml
PLANTUML_SYMLINK_LOCATION=/usr/local/bin/plantuml

if ! [[ -f "${PLANTUML_SYMLINK_LOCATION}" ]]; then
    PLANTUML_BINARY_LOCATION="$(which plantuml)"
    log_debug "Setting symlink to plantuml binary ${PLANTUML_BINARY_LOCATION} at location ${PLANTUML_SYMLINK_LOCATION}"
    ln -s "${PLANTUML_BINARY_LOCATION}" "${PLANTUML_SYMLINK_LOCATION}"
fi

export PATH="${CURRENT_DIRECTORY}/bin:${PATH}"

mdbook "$@"
