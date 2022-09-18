#!/usr/bin/env bash
set -euo pipefail

: "${ETCD_VERSION:?ETCD_VERSION must be defined}"
: "${VM_MOUNT_LOCATION:?VM_MOUNT_LOCATION must be defined}"
: "${CNT_VMS:?CNT_VMS must be defined}"
: "${HOSTNAME_PREFIX:?HOSTNAME_PREFIX must be defined}"
: "${STARTING_IP_SUFFIX:?STARTING_IP_SUFFIX: must be defined}"
: "${STARTING_IP_PREFIX:?STARTING_IP_PREFIX: must be defined}"
: "${CPU_ARCH:?CPU_ARCH: must be defined}"
: "${DOWNLOAD_CACHE_DIR:?DOWNLOAD_CACHE_DIR: must be defined}"
: "${VM_RUNTIME:?VM_RUNTIME: must be defined}"

# Download and install etcd
function download_and_install_etcd() {
    log_info "Starting download_and_install_etcd on host $(hostname -f)"
    local etcd_download_dir="${DOWNLOAD_CACHE_DIR}"
    local etcd_tarball_name=etcd.tar.gz
    local etcd_tarball_path="${etcd_download_dir}/${etcd_tarball_name}"

    local etcd_unpacked_dir_name
    etcd_unpacked_dir_name="etcd-${ETCD_VERSION}-linux-${CPU_ARCH}"

    sudo mkdir -p "${DOWNLOAD_CACHE_DIR}"
    sudo chmod 777 "${DOWNLOAD_CACHE_DIR}"
    sudo chmod 777 "${DOWNLOAD_CACHE_DIR}"/* || true
    log_info "Starting to kill etcd if it was already running"
    sudo systemctl stop etcd || :
    sudo systemctl disable etcd 2>/dev/null || :
    sudo systemctl reload 2>/dev/null || :
    sudo systemctl status etcd 2>/dev/null || :
    pkill etcd || log_debug "cannot kill -- etcd is not running"
    sudo systemctl kill --force etcd 2>/dev/null || log_debug "etcd was not running"
    sudo rm -rf /var/lib/etcd

    cd "${DOWNLOAD_CACHE_DIR}"

    log_info "Starting to download etcd"
    if ! [[ -f ${etcd_tarball_path} ]]; then
        log_debug "etcd not found in the cache, downloading it"
        curl --fail -L -o "${etcd_tarball_path}" \
            "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/${etcd_unpacked_dir_name}.tar.gz"
    else
        log_info "etcd download found in the cache"
    fi

    (cd "${etcd_download_dir}" && tar -xf "${etcd_tarball_name}")
    ls -ld "${etcd_download_dir}/${etcd_unpacked_dir_name}"
    sudo cp "${etcd_download_dir}/${etcd_unpacked_dir_name}"/etcd* /usr/local/bin/

    # Configure etcd
    sudo mkdir -p /etc/etcd /var/lib/etcd
    sudo chmod 700 /var/lib/etcd
    sudo cp \
        "${VM_MOUNT_LOCATION}/output/certificates/ca.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/kubernetes-key.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/kubernetes.pem" \
        /etc/etcd/
    log_info "Completed download_and_install_etcd"
}

function generate_etcd_config() {
    log_info "Starting generate_etcd_config on host $(hostname -f)"
    : "${1:? Must supply the vm number as the first arg}"
    local vm_number="${1}"
    local instance="${HOSTNAME_PREFIX}${vm_number}"
    local this_vm_ip_suffix=$((STARTING_IP_SUFFIX + vm_number - 1))
    local ip_suffix_iterator="${STARTING_IP_SUFFIX}"

    INTERNAL_IP="${STARTING_IP_PREFIX}.${this_vm_ip_suffix}"
    local vm_public_ip_iterator=1
    while [ "$vm_public_ip_iterator" -le "${CNT_VMS}" ]; do
        local vm_name="${HOSTNAME_PREFIX}${vm_public_ip_iterator}"
        KUBERNETES_PUBLIC_ADDRESS+=("${vm_name}=https://${STARTING_IP_PREFIX}.${ip_suffix_iterator}:2380")
        ip_suffix_iterator=$((ip_suffix_iterator + 1))
        vm_public_ip_iterator=$((vm_public_ip_iterator + 1))
    done

    PUBLIC_TRANSLATED_IPS="$(
        export IFS=,
        echo "${KUBERNETES_PUBLIC_ADDRESS[*]}"
    )"

    log_info "etcd member IPs for host ${instance} (INTERNAL_IP=${INTERNAL_IP}, count=${#KUBERNETES_PUBLIC_ADDRESS[@]}): ${PUBLIC_TRANSLATED_IPS}"

    local cluster_state=new
    local initial_peers=${PUBLIC_TRANSLATED_IPS}
    log_debug "${instance} will advertise etcd initial_peers as ${PUBLIC_TRANSLATED_IPS}"

    cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
Environment=ETCD_UNSUPPORTED_ARCH=arm64
ExecStart=/usr/local/bin/etcd \\
  --name ${instance} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster ${initial_peers} \\
  --initial-cluster-state ${cluster_state} \\
  --data-dir=/var/lib/etcd \\
  --logger=zap \\
  --log-level=info
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    #   --initial-cluster-token etcd-cluster-${vm_number} \\

    STARTING_IP_SUFFIX=$((STARTING_IP_SUFFIX + 1))
    log_info "Completed generate_etcd_config"
}

function start_etcd() {
    log_info "Starting start_etcd on host $(hostname -f)"
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl clean etcd || :
    log_info "About to start ectd"
    sudo systemctl start --no-block etcd
    log_info "Completed start_etcd"
}

function check_all_etcds_online() {
    log_info "Starting check_all_etcds_online"
    local instance="${HOSTNAME_PREFIX}1"

    run_command_on_remote_host "${VM_RUNTIME}" "${instance}" "list etcd members" <<EOF
        log_info "Checking etcd liveness from host \$(hostname -f)"
        sudo ETCDCTL_API=3 etcdctl member list \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/etcd/ca.pem \
            --cert=/etc/etcd/kubernetes.pem \
            --key=/etc/etcd/kubernetes-key.pem \
            --dial-timeout=15s \
            --command-timeout=10s
EOF
    log_info "Completed check_all_etcds_online"
}

function main() {
    local install_iterator=1
    while [ "$install_iterator" -le "${CNT_VMS}" ]; do
        local vm_name="${HOSTNAME_PREFIX}${install_iterator}"
        run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "install etcd and generate config" <<EOF
            export STARTING_IP_SUFFIX="${STARTING_IP_SUFFIX}"
            export STARTING_IP_PREFIX="${STARTING_IP_PREFIX}"
            source "${VM_MOUNT_LOCATION}/scripts/-1-environment.sh"
            source "${VM_MOUNT_LOCATION}/scripts/11-bootstrap-etcd.sh"

            download_and_install_etcd
            generate_etcd_config "${install_iterator}"
EOF
        install_iterator=$((install_iterator + 1))
    done

    local start_etcd_iterator=1
    while [ "$start_etcd_iterator" -le "${CNT_VMS}" ]; do
        local vm_name="${HOSTNAME_PREFIX}${start_etcd_iterator}"
        run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "start etcd on host" <<EOF
            export STARTING_IP_SUFFIX="${STARTING_IP_SUFFIX}"
            export STARTING_IP_PREFIX="${STARTING_IP_PREFIX}"
            source "${VM_MOUNT_LOCATION}/scripts/-1-environment.sh"
            source "${VM_MOUNT_LOCATION}/scripts/11-bootstrap-etcd.sh"
            start_etcd
EOF
        start_etcd_iterator=$((start_etcd_iterator + 1))
    done
    log_info "Waiting for etcd servers to start... sleeping first"
    sleep 15
    check_all_etcds_online

}

# https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [[ "${sourced}" -eq 0 ]]; then
    log_debug "Invoking the driver etcd installation script"
    main
else
    log_debug "etcd bootstrapping script is being sourced"
fi
