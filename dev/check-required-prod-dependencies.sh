#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

export PROJECT_ROOT
PROJECT_ROOT=$(cd "${CURRENT_DIRECTORY}/.." && pwd)

# Load helper functions
# shellcheck source=../scripts/helpers/logging.sh
source "${PROJECT_ROOT}/scripts/helpers/logging.sh"

FAILED_DEPS=0

if ! which cfssl; then
    log_error "cfssl binary missing on the path (PATH=${PATH}). Please install it from https://github.com/cloudflare/cfssl"
    FAILED_DEPS=1
fi

if ! which cfssljson; then
    log_error "cfssljson binary missing on the path (PATH=${PATH}). Please install it from https://github.com/cloudflare/cfssl"
    FAILED_DEPS=1
fi

if ! which docker; then
    log_error "docker binary missing on the path (PATH=${PATH}). Please install it from https://docs.docker.com/engine/install"
    FAILED_DEPS=1
fi

if ! which kubectl; then
    log_error "kubectl binary missing on the path (PATH=${PATH}). Please install it from https://kubernetes.io/docs/tasks/tools"
    FAILED_DEPS=1
fi

if ! which openssl; then
    log_error "openssl binary missing on the path (PATH=${PATH}). Please install it using your system manager"
    FAILED_DEPS=1
fi

if [[ ${FAILED_DEPS} -eq 1 ]]; then
    log_error "At least one required dependency is missing. Check the logs above and re-run to validate"
    exit 2
else
    log_info "All required production dependencies are installed"
fi
