#!/usr/bin/env bash
export HELPERS_DIR
HELPERS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${HELPERS_DIR}/logging.sh"

function run_command_on_remote_host() {
    : "${1:?Must specify the container runtime as the first parameter}"
    : "${2:?Must specify the vm number as the second parameter}"

    local container_runtime="${1}"
    local vm_name="${2}"
    local script_description="${3:-no-description}"

    local standard_in_contents
    standard_in_contents=$(cat -)

    local command_prefix="""
# set -x
set -euo pipefail
source ${HELPERS_DIR}/logging.sh
"""

    local command_suffix="""
"""

    local full_command="""
####### Prefix: start
${command_prefix}
####### Prefix: end
####### Standard in: start
${standard_in_contents}
####### Standard in: end
####### Suffix: start
${command_suffix}
####### Suffix: end
"""
    # log_debug "Command to run on ${vm_name}: ${full_command}"

    if [[ "${container_runtime}" = "docker" ]]; then
        log_info "Starting to run docker command on ${vm_name} -- ${script_description}"
        docker exec --tty "${vm_name}" bash -c "${full_command}"
    elif [[ "${container_runtime}" = "lima" ]]; then
        log_info "Starting to run lima command on ${vm_name} -- ${script_description}"
        limactl shell "${vm_name}" <<<"${full_command}"
    else
        echo "Container runtime not recognized for running remote command: ${container_runtime}"
        exit 1
    fi
    log_info "end of command on ${vm_name} -- ${script_description}"
}

export -f run_command_on_remote_host
