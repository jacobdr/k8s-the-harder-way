#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ROOT?? PROJECT_ROOT must be defined}"
: "${VM_RUNTIME?? VM_RUNTIME must be defined}"
: "${CNT_VMS:?CNT_VMS must be defined}"
: "${HOSTNAME_PREFIX:?HOSTNAME_PREFIX must be defined}"
: "${DOWNLOAD_CACHE_DIR:?DOWNLOAD_CACHE_DIR must be defined}"

log_info "Starting to create ${CNT_VMS} VMs with runtime ${VM_RUNTIME}"

if [[ "${VM_RUNTIME}" = "docker" ]]; then
    docker build -f "${PROJECT_ROOT}/Dockerfile" -t k8s-hard-way "${PROJECT_ROOT}"
    docker ps -a | grep k8s-hard-way | awk '{print $1}' | xargs docker rm -f
    mkdir -p "${PROJECT_ROOT}/output/downloads"
elif [[ "${VM_RUNTIME}" = "lima" ]]; then
    sudo rm -rf /private/var/run/lima
    limactl sudoers | sudo tee /private/etc/sudoers.d/lima 1>/dev/null
fi

WORKER_ITERATOR=1

while [ "$WORKER_ITERATOR" -le "${CNT_VMS}" ]; do
    log_info "Starting to launch VM ${WORKER_ITERATOR} of ${CNT_VMS} using ${VM_RUNTIME}"
    VM_HOSTNAME="${HOSTNAME_PREFIX}${WORKER_ITERATOR}"
    if [[ "${VM_RUNTIME}" = "docker" ]]; then
        docker rm -f --volumes "${VM_HOSTNAME}"
        docker run \
            --name "${VM_HOSTNAME}" \
            --hostname="${VM_HOSTNAME}" \
            --detach \
            --privileged \
            --cap-add=NET_ADMIN \
            --tmpfs /run/lock \
            --volume "${VM_HOSTNAME}-temp:/tmp" \
            --volume "${PROJECT_ROOT}:${PROJECT_ROOT}:ro" \
            --volume "${PROJECT_ROOT}/output/downloads:${DOWNLOAD_CACHE_DIR}" \
            k8s-hard-way

    elif [[ "${VM_RUNTIME}" = "lima" ]]; then
        limactl stop "${VM_HOSTNAME}" &>/dev/null || limactl stop "${VM_HOSTNAME}" --force &>/dev/null || true
        limactl delete "${VM_HOSTNAME}" &>/dev/null || limactl delete "${VM_HOSTNAME}" --force &>/dev/null || true
        true | (limactl start --name "${VM_HOSTNAME}" "${PROJECT_ROOT}/lima-config.yaml") 2>&1 | cat # grep 'progress|requirement|WARN|FAT'
    fi

    log_info "Successfully launched VM ${WORKER_ITERATOR} (runtime: ${VM_RUNTIME})"
    WORKER_ITERATOR=$((WORKER_ITERATOR + 1))
done
