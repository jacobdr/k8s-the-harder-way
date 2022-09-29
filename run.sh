#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${CURRENT_DIRECTORY}/scripts/-1-environment.sh"

log_info "Starting to run cert generation process with the following variables...."
log_info "OUTPUT_DIR=${OUTPUT_DIR}"
log_info "CSR_DIR=${CSR_DIR}"
printf "..........\n\n"

# Create an output directory to house all sensitive outputs
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_CERTS}"
mkdir -p "${KUBE_CONFIG_DIR}"
"${PROJECT_ROOT}"/scripts/0-initialize-vms.sh

# NOTE: need to load the networking configuration AFTER the vms have already
# been started
# shellcheck source=./scripts/helpers/networking.sh
source "${PROJECT_ROOT}/scripts/helpers/networking.sh"

"${PROJECT_ROOT}"/scripts/1-generate-ca.sh
"${PROJECT_ROOT}"/scripts/2-generate-admin-client-cert.sh
"${PROJECT_ROOT}"/scripts/3-generate-vm-kubelet-certs.sh
"${PROJECT_ROOT}"/scripts/4-generate-controller-manager-cert.sh
"${PROJECT_ROOT}"/scripts/5-generate-kube-proxy-cert.sh
"${PROJECT_ROOT}"/scripts/6-generate-kube-scheduler-cert.sh
"${PROJECT_ROOT}"/scripts/7-generate-api-server-certificates.sh
"${PROJECT_ROOT}"/scripts/8-generate-service-account-cert.sh
"${PROJECT_ROOT}"/scripts/9-generate-kube-configs.sh
"${PROJECT_ROOT}"/scripts/10-generate-clustter-encryption-keys.sh
"${PROJECT_ROOT}"/scripts/11-bootstrap-etcd.sh
"${PROJECT_ROOT}"/scripts/12-bootstrap-k8s-control-plane.sh
"${PROJECT_ROOT}"/scripts/13-bootstrap-workers.sh
"${PROJECT_ROOT}"/scripts/14-setup-cluster-dns.sh
"${PROJECT_ROOT}"/scripts/15-install-load-balancer-controller.sh
"${PROJECT_ROOT}"/scripts/16-setup-nginx-ingress.sh
# "${PROJECT_ROOT}"/scripts/17-bootstrap-argocd.sh
