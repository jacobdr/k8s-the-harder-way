#!/usr/bin/env bash
: "${VM_RUNTIME:?VM_RUNTIME must be defined}"
: "${HELPERS_DIR:?HELPERS_DIR must be defined}"
: "${HOSTNAME_PREFIX:?HOSTNAME_PREFIX must be defined}"

# shellcheck source=logging.sh
source "${HELPERS_DIR}/logging.sh"

export CLUSTER_CIDR_RANGE="10.200.0.0/16"

# TODO: Add better checks of the sequential IP addresses

if [[ "${VM_RUNTIME}" = "docker" ]]; then
    # shellcheck source=docker.sh
    source "${HELPERS_DIR}/docker.sh"
    DOCKER_FIRST_VM_IP="$(docker_get_bridge_container_ips | jq 'select(.Name == "vm1") | .IPv4Address')"
    log_info "Processed DOCKER_FIRST_VM_IP as ${DOCKER_FIRST_VM_IP}"
    if [[ ${DOCKER_FIRST_VM_IP} =~ \"(.+)\.(.+)/(.*)\" ]]; then
        export STARTING_IP_PREFIX="${BASH_REMATCH[1]}"
        export STARTING_IP_SUFFIX="${BASH_REMATCH[2]}"
        export IP_CIDR="${BASH_REMATCH[3]}"
    else
        echo "Failed to match docker STARTING_IP_PREFIX: DOCKER_FIRST_VM_IP=${DOCKER_FIRST_VM_IP}"
        exit 1
    fi
elif [[ "${VM_RUNTIME}" = "lima" ]]; then
    LIMA_FIRST_VM_INTERFACE=$(limactl shell "${HOSTNAME_PREFIX}1" <<<"ip a show lima1 | grep inet | head -n 1")
    echo "JDR DEBUG LIMA_FIRST_VM_INTERFACE=${LIMA_FIRST_VM_INTERFACE}"
    export STARTING_IP_PREFIX="192.168.105"
    export STARTING_IP_SUFFIX=4
    export IP_CIDR=255
else
    echo "Unsupported runtime"
    exit 1
fi

# TOOD: Make this HA by running an HA proxy in front or something
export KUBERNETES_PUBLIC_ADDRESS="${STARTING_IP_PREFIX}.${STARTING_IP_SUFFIX}"
export EXTERNAL_INGRESS_SUBNET="${STARTING_IP_PREFIX}.240/28"

log_info "Networking -- STARTING_IP_PREFIX=${STARTING_IP_PREFIX} STARTING_IP_SUFFIX=${STARTING_IP_SUFFIX} IP_CIDR=${IP_CIDR}"
log_info "Networking -- KUBERNETES_PUBLIC_ADDRESS=${KUBERNETES_PUBLIC_ADDRESS} EXTERNAL_INGRESS_SUBNET=${EXTERNAL_INGRESS_SUBNET}"
