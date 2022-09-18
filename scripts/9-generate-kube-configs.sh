#!/usr/bin/env bash
set -euo pipefail

: "${CNT_VMS:?CNT_VMS must be defined}"
: "${CSR_DIR:?CSR_DIR must be defined}"
: "${KUBE_CONFIG_DIR:?KUBE_CONFIG_DIR must be defined}"
: "${OUTPUT_DIR_CERTS:?OUTPUT_DIR_CERTS must be defined}"
: "${KUBERNETES_PUBLIC_ADDRESS:?KUBERNETES_PUBLIC_ADDRESS must be defined}"

function generate_kubelet_config() {
    : "${1:? Must supply the vm number as the first arg}"
    local vm_number="${1}"
    local instance="${HOSTNAME_PREFIX}${vm_number}"

    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority="${OUTPUT_DIR_CERTS}/ca.pem" \
        --embed-certs=true \
        --server="https://${KUBERNETES_PUBLIC_ADDRESS}:6443" \
        --kubeconfig="${KUBE_CONFIG_DIR}/${instance}.kubeconfig"

    kubectl config set-credentials "system:node:${instance}" \
        --client-certificate="${OUTPUT_DIR_CERTS}/${instance}.pem" \
        --client-key="${OUTPUT_DIR_CERTS}/${instance}-key.pem" \
        --embed-certs=true \
        --kubeconfig="${KUBE_CONFIG_DIR}/${instance}.kubeconfig"

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user="system:node:${instance}" \
        --kubeconfig="${KUBE_CONFIG_DIR}/${instance}.kubeconfig"

    kubectl config use-context default --kubeconfig="${KUBE_CONFIG_DIR}/${instance}.kubeconfig"
}

function generate_kube_proxy_config() {
    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority="${OUTPUT_DIR_CERTS}/ca.pem" \
        --embed-certs=true \
        --server="https://${KUBERNETES_PUBLIC_ADDRESS}:6443" \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-proxy.kubeconfig"

    kubectl config set-credentials system:kube-proxy \
        --client-certificate="${OUTPUT_DIR_CERTS}/kube-proxy.pem" \
        --client-key="${OUTPUT_DIR_CERTS}/kube-proxy-key.pem" \
        --embed-certs=true \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-proxy.kubeconfig"

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=system:kube-proxy \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-proxy.kubeconfig"

    kubectl config use-context default --kubeconfig="${KUBE_CONFIG_DIR}/kube-proxy.kubeconfig"
}

function generate_kube_controller_manager_config() {
    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority="${OUTPUT_DIR_CERTS}/ca.pem" \
        --embed-certs=true \
        --server=https://127.0.0.1:6443 \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-controller-manager.kubeconfig"

    kubectl config set-credentials system:kube-controller-manager \
        --client-certificate="${OUTPUT_DIR_CERTS}/kube-controller-manager.pem" \
        --client-key="${OUTPUT_DIR_CERTS}/kube-controller-manager-key.pem" \
        --embed-certs=true \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-controller-manager.kubeconfig"

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=system:kube-controller-manager \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-controller-manager.kubeconfig"

    kubectl config use-context default --kubeconfig="${KUBE_CONFIG_DIR}/kube-controller-manager.kubeconfig"
}

function generate_kube_scheduler_config() {
    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority="${OUTPUT_DIR_CERTS}/ca.pem" \
        --embed-certs=true \
        --server=https://127.0.0.1:6443 \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-scheduler.kubeconfig"

    kubectl config set-credentials system:kube-scheduler \
        --client-certificate="${OUTPUT_DIR_CERTS}/kube-scheduler.pem" \
        --client-key="${OUTPUT_DIR_CERTS}/kube-scheduler-key.pem" \
        --embed-certs=true \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-scheduler.kubeconfig"

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=system:kube-scheduler \
        --kubeconfig="${KUBE_CONFIG_DIR}/kube-scheduler.kubeconfig"

    kubectl config use-context default --kubeconfig="${KUBE_CONFIG_DIR}/kube-scheduler.kubeconfig"
}

function generate_admin_config() {
    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority="${OUTPUT_DIR_CERTS}/ca.pem" \
        --embed-certs=true \
        --server=https://127.0.0.1:6443 \
        --kubeconfig="${KUBE_CONFIG_DIR}/admin.kubeconfig"

    kubectl config set-credentials admin \
        --client-certificate="${OUTPUT_DIR_CERTS}/admin.pem" \
        --client-key="${OUTPUT_DIR_CERTS}/admin-key.pem" \
        --embed-certs=true \
        --kubeconfig="${KUBE_CONFIG_DIR}/admin.kubeconfig"

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=admin \
        --kubeconfig="${KUBE_CONFIG_DIR}/admin.kubeconfig"

    kubectl config use-context default --kubeconfig="${KUBE_CONFIG_DIR}/admin.kubeconfig"
}

KUBELET_ITERATOR=1

function main() {
    log_info "Starting to generate the vm kubeconfigs"
    while [ "$KUBELET_ITERATOR" -le "${CNT_VMS}" ]; do
        log_info "Starting to generate the kubelet config for vm ${KUBELET_ITERATOR}"
        generate_kubelet_config ${KUBELET_ITERATOR}
        KUBELET_ITERATOR=$((KUBELET_ITERATOR + 1))
    done

    log_info "Starting to kube proxy kubeconfig"
    generate_kube_proxy_config
    log_info "Starting to kube controller manager kubeconfig"
    generate_kube_controller_manager_config
    log_info "Starting to kube scheduler kubeconfig"
    generate_kube_scheduler_config
    log_info "Starting to kube admin kubeconfig"
    generate_admin_config
    log_info "Completed generating the vm kubeconfigs"
}

main
