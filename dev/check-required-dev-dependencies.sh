#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

export PROJECT_ROOT
PROJECT_ROOT=$(cd "${CURRENT_DIRECTORY}/.." && pwd)

# shellcheck source=../scripts/helpers/logging.sh
source "${PROJECT_ROOT}/scripts/helpers/logging.sh"

FAILED_DEPS=0

if ! which mdbook &>/dev/null; then
    log_error "mdbook binary missing on the path (PATH=${PATH}). Please install it from https://github.com/rust-lang/mdBook"
    FAILED_DEPS=1
fi

if ! which plantuml &>/dev/null; then
    log_error "plantuml binary missing on the path (PATH=${PATH}). Please install it using a system manager (also see https://plantuml.com/starting)"
    FAILED_DEPS=1
fi

if ! which cargo &>/dev/null; then
    log_error "cargo binary (from rust) missing on the path (PATH=${PATH}). Please install it using a system manager"
    log_error "We use cargo to manage preprocessors for the docs"
    FAILED_DEPS=1
fi

if [[ ${FAILED_DEPS} -eq 1 ]]; then
    log_error "At least one required dependency is missing. Check the logs above and re-run to validate"
    exit 2
else
    log_info "All required development dependencies are installed"
fi
