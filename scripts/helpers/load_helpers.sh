#!/usr/bin/env bash

HELPERS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# NOTE: DO NOT LOAD THE NETWORKING CONFIG HERE -- it should only be run
# from the host machine and needs to happen after VM startup
# shellcheck source=./docker.sh
source "${HELPERS_DIR}/docker.sh"
# shellcheck source=./logging.sh
source "${HELPERS_DIR}/logging.sh"
# shellcheck source=./remote_command.sh
source "${HELPERS_DIR}/remote_command.sh"
