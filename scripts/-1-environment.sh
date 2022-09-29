#!/usr/bin/env bash
CURRENT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

export PROJECT_ROOT
PROJECT_ROOT=$(cd "${CURRENT_DIRECTORY}/.." && pwd)

# Runtime to use -- available options: docker | lima
export VM_RUNTIME=docker

# Constants used by the scripts
export HELPERS_DIR="${PROJECT_ROOT}/scripts/helpers"
export OUTPUT_DIR="${PROJECT_ROOT}/output"
export OUTPUT_DIR_CERTS="${OUTPUT_DIR}/certificates"
export KUBE_CONFIG_DIR="${OUTPUT_DIR}/kube-configs"
export CSR_DIR="${PROJECT_ROOT}/csr"
export CNT_VMS=3
export HOSTNAME_PREFIX="vm"

RAW_CPU_ARCH="$(uname -m)"
if [[ "${RAW_CPU_ARCH}" =~ "arm64" || "${RAW_CPU_ARCH}" =~ "aarch64" ]]; then
    export CPU_ARCH="arm64"
else
    export CPU_ARCH="amd64"
fi

# Load helper functions
# shellcheck source=./helpers/load_helpers.sh
source "${HELPERS_DIR}/load_helpers.sh"

# https://github.com/etcd-io/etcd/pull/11225
export ETCD_VERSION="v3.4.15"
export K8S_VERSION="v1.21.0"
export RUNC_VERSION="v1.1.4"
export CNI_PLUGIN_VERSION="v1.1.1"
# Note: omit the v
export NERDCTL_VERSION="0.23.0"
export HELM_VERSION="v3.10.0"
# Note: omit the v
export CONTAINERD_VERSION="1.6.8"
export VM_MOUNT_LOCATION="${PROJECT_ROOT}"

export DOWNLOAD_CACHE_DIR="/tmp/lima/downloads"
