#!/usr/bin/env bash
set -euo pipefail

: "${RUNC_VERSION?: RUNC_VERSION must be defined}"
: "${CNI_PLUGIN_VERSION?: CNI_PLUGIN_VERSION must be defined}"
: "${CONTAINERD_VERSION?: CONTAINERD_VERSION must be defined}"
: "${HELM_VERSION?: HELM_VERSION must be defined}"
: "${NERDCTL_VERSION?: NERDCTL_VERSION must be defined}"
: "${VM_MOUNT_LOCATION?: CONTAINERD_VERSION must be defined}"
: "${CLUSTER_CIDR_RANGE?: CLUSTER_CIDR_RANGE must be defined}"
: "${STARTING_IP_SUFFIX?: STARTING_IP_SUFFIX must be defined}"
: "${STARTING_IP_PREFIX?: STARTING_IP_PREFIX must be defined}"
: "${CPU_ARCH?: CPU_ARCH must be defined}"
: "${VM_RUNTIME?: VM_RUNTIME must be defined}"
: "${DOWNLOAD_CACHE_DIR?: DOWNLOAD_CACHE_DIR must be defined}"

PRIVATE_CIDR_PREFIX="10.10"
PRIVATE_CIDR_SUBNET_MASK="26"

function install_system_libs() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    local NERDCTL_TARBALL=nerdctl-${NERDCTL_VERSION}-linux-${CPU_ARCH}.tar.gz
    local HELM_TARBALL=helm-${HELM_VERSION}-linux-${CPU_ARCH}.tar.gz
    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "install system libraries on k8s worker" <<EOC
    export CPU_ARCH=${CPU_ARCH}
    export NERDCTL_TARBALL=${NERDCTL_TARBALL}
    sudo apt-get update
    sudo apt-get install -y socat conntrack ipset iproute2 kmod dnsutils cgroupfs-mount iputils-ping
    cd ${DOWNLOAD_CACHE_DIR}

    if ! which nerdctl; then
        log_info "need to install nerdctl binary"
        curl -O -L --fail https://github.com/containerd/nerdctl/releases/download/v0.23.0/${NERDCTL_TARBALL}
        tar xzf ${NERDCTL_TARBALL}
        sudo cp /tmp/nerdctl /usr/local/bin
    else
        log_info "nerdctl inalready installed"
    fi

    if ! which helm; then
        log_info "need to install helm binary"
        # https://helm.sh/docs/intro/install/
            curl -O -L https://get.helm.sh/${HELM_TARBALL}
            tar xf "${HELM_TARBALL}"
            sudo cp linux-${CPU_ARCH}/helm /usr/local/bin
    else
        log_info "helm inalready installed"
    fi
EOC
}

function install_k8s_components() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"

    COMPONENTS=(
        "https://github.com/kubernetes-sigs/cri-tools/releases/download/${K8S_VERSION}/crictl-${K8S_VERSION}-linux-${CPU_ARCH}.tar.gz"
        "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${CPU_ARCH}"
        "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${CPU_ARCH}-${CNI_PLUGIN_VERSION}.tgz"
        "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${CPU_ARCH}.tar.gz"
        "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${CPU_ARCH}/kubectl"
        "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${CPU_ARCH}/kube-proxy"
        "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${CPU_ARCH}/kubelet"
    )

    for component_url in "${COMPONENTS[@]}"; do
        local binary_name
        binary_name="$(basename "${component_url}")"

        run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker download ${binary_name}" <<EOC
            cd ${DOWNLOAD_CACHE_DIR}

            if ! [[ -f  "${binary_name}" ]]; then
                log_info "Cache miss on binary download ${binary_name}. Cache contents \$(ls .)"
                log_info "installing ${binary_name}: ${component_url}"
                if ! curl -L --fail -O "${component_url}"; then
                    rm -rf ${binary_name}
                fi
            else
                log_info "binary ${binary_name} already downloaded"
            fi

EOC
    done

    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker move binaries" <<EOC
    sudo mkdir -p \
        /etc/cni/net.d \
        /opt/cni/bin \
        /var/lib/kubelet \
        /var/lib/kube-proxy \
        /var/lib/kubernetes \
        /var/run/kubernetes \

    cd ${DOWNLOAD_CACHE_DIR}
    mkdir -p containerd
    tar -xf crictl-${K8S_VERSION}-linux-${CPU_ARCH}.tar.gz
    tar -xf containerd-${CONTAINERD_VERSION}-linux-${CPU_ARCH}.tar.gz -C containerd
    sudo tar -xf cni-plugins-linux-${CPU_ARCH}-${CNI_PLUGIN_VERSION}.tgz -C /opt/cni/bin/
    sudo cp runc.${CPU_ARCH} runc
    sudo chmod +x crictl kubectl kube-proxy kubelet runc
    for binary_to_move in crictl kubectl kube-proxy kubelet runc; do
        if ! [[ -f "/usr/local/bin/\${binary_to_move}" ]]; then
            sudo cp \${binary_to_move} /usr/local/bin/
        fi
    done
    sudo cp containerd/bin/* /bin/
EOC
}

function configure_cni_neworking() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    local pod_cidr_range="${2:?must supply a pod cidr range as the second parameter}"
    # https://github.com/containernetworking/cni/blob/main/SPEC.md
    local cni_spec_version="0.4.0"

    log_info "Configuring CNI networking for host ${vm_name} with CIDR range: ${pod_cidr_range}"

    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker setup CNI networking" <<EOC
    mkdir -p /etc/cni/net.d/
    cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "${cni_spec_version}",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${pod_cidr_range}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

    cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "${cni_spec_version}",
    "name": "lo",
    "type": "loopback"
}
EOF
EOC
    log_info "CNI networking setup finished"
}

function configure_containerd() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    log_info "Starting to configure containerd"
    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker containerd setup" <<EOC
    sudo mkdir -p /etc/containerd/

    cat <<EOF | sudo tee /etc/containerd/config.toml
# https://github.com/containerd/containerd/blob/main/docs/ops.md
version = 2

# persistent data location
root = "/tmp/containerd"
# runtime state information
state = "/run/containerd"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "native"
EOF

    cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
# ExecStartPre=-/sbin/modprobe overlay
ExecStart=/bin/containerd --log-level=debug
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
EOC
    log_info "Containerd configuration completed"
}

function configure_kubelet() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    local pod_cidr_range="${2:?must supply a pod cidr range as the second parameter}"
    log_info "Starting to configure kubelet component"

    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker kubelet configuration" <<EOC
    mkdir -p /var/lib/kubelet

    sudo cp \
        "${VM_MOUNT_LOCATION}/output/certificates/${vm_name}-key.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/${vm_name}.pem" \
        /var/lib/kubelet/

    sudo cp "${VM_MOUNT_LOCATION}/output/kube-configs/${vm_name}.kubeconfig" /var/lib/kubelet/kubeconfig
    sudo cp "${VM_MOUNT_LOCATION}/output/certificates/ca.pem" /var/lib/kubernetes/

    cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${pod_cidr_range}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "4m"
tlsCertFile: "/var/lib/kubelet/${vm_name}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${vm_name}-key.pem"
failSwapOn: false
memorySwap:
  swapBehavior: LimitedSwap
cgroupDriver: systemd
EOF

    cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --hostname-override=${vm_name} \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=3
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
EOC
    log_info "Finished configuring kubelet component"
}

function configure_kube_proxy() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    local vm_public_interface_ip="${2:? expected the VM public interface ip address to be provide}"
    log_info "Starting to configure kube-proxy"

    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker kube proxy setup" <<EOC

    sudo cp "${VM_MOUNT_LOCATION}/output/kube-configs/kube-proxy.kubeconfig" /var/lib/kube-proxy/kubeconfig

    cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
# mode: "iptables"
mode: "ipvs"
# https://serverfault.com/questions/1063166/kube-proxy-wont-start-in-minikube-because-of-permission-denied-issue-with-proc
conntrack:
    maxPerCore: 0
clusterCIDR: "${CLUSTER_CIDR_RANGE}"
EOF

    cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
    --hostname-override=${vm_name} \\
    --config=/var/lib/kube-proxy/kube-proxy-config.yaml \\
    --bind-address=${vm_public_interface_ip} \\
  --v=3
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
EOC
    log_info "Finished configuring kube-proxy"
}

function stop_system_services() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker stop services" <<EOF
        sudo systemctl daemon-reload
        sudo systemctl stop containerd kubelet kube-proxy 2>/dev/null || echo "kube worker components were not running"
        pkill containerd || :
        pkill kubelet  || :
        pkill kube-proxy || :

EOF
}

function start_system_services() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker start services" <<EOF
        sudo systemctl daemon-reload
        sudo systemctl enable containerd kubelet kube-proxy
        sudo systemctl clean containerd kubelet kube-proxy || :
        sudo systemctl stop containerd kubelet kube-proxy
        sudo systemctl start containerd kubelet kube-proxy

EOF
}

# for now we just modify the /etc/hosts file
function setup_interhost_networking() {
    local vm_name="${1:? expected the vm name to be supplied as the first parameter}"
    local vm_number="${2:? expected the vm number to be supplied as the second parameter}"

    local iterator=1
    local delete_pattern="-DELETE-"
    local hosts_file_contents="### START CUSTOM HOST MAP ${delete_pattern}"

    while [ "$iterator" -le "${CNT_VMS}" ]; do
        local this_vm_ip_suffix=$((STARTING_IP_SUFFIX + iterator - 1))
        local vm_hostname="${HOSTNAME_PREFIX}${iterator}"
        local vm_ip="${STARTING_IP_PREFIX}.${this_vm_ip_suffix}"
        hosts_file_contents="${hosts_file_contents}\n${vm_ip} ${vm_hostname} #${delete_pattern}"
        iterator=$((iterator + 1))
    done

    hosts_file_contents="${hosts_file_contents}\n### END CUSTOM HOST MAP ${delete_pattern}\n"
    # shellcheck disable=SC2059
    printf "Network map file: ${hosts_file_contents}"

    local unix_seconds
    unix_seconds="$(date +%s)"

    export temp_network_map_file=/tmp/temp-network-map.txt
    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker setup inter-host routing" <<EOC
        sudo cp /etc/hosts "/etc/hosts.backup.${unix_seconds}"
        cp /etc/hosts "${temp_network_map_file}"
        sed -i "/${delete_pattern}/d" "${temp_network_map_file}"
        printf "${hosts_file_contents}" >>"${temp_network_map_file}"
        log_info "Modified hosts file is at: ${temp_network_map_file} (hosts file permission: \$(ls -l /etc/hosts))"
        cat ${temp_network_map_file}
        sudo su root
        cat ${temp_network_map_file} > /etc/hosts
        exit
EOC

    # Add routes to all the hosts
    local ip_routing_iterator_inner=1
    local routing_commands=()

    local current_vm_ip_suffix=$((STARTING_IP_SUFFIX + vm_number - 1))
    local current_vm_ip="${STARTING_IP_PREFIX}.${current_vm_ip_suffix}"

    while [ "$ip_routing_iterator_inner" -le "${CNT_VMS}" ]; do
        local this_vm_ip_suffix_inner=$((STARTING_IP_SUFFIX + ip_routing_iterator_inner - 1))
        local vm_ip_inner="${STARTING_IP_PREFIX}.${this_vm_ip_suffix_inner}"
        local cluster_internal_route="${PRIVATE_CIDR_PREFIX}.${this_vm_ip_suffix_inner}.0/${PRIVATE_CIDR_SUBNET_MASK}"

        if [[ "${current_vm_ip}" != "${vm_ip_inner}" ]]; then
            routing_commands+=(
                "sudo ip route delete ${cluster_internal_route} || echo route did not exist"
                "sudo ip route add ${cluster_internal_route} via ${vm_ip_inner}"
            )
        fi

        ip_routing_iterator_inner=$((ip_routing_iterator_inner + 1))
    done

    local cnt_route_commands=${#routing_commands[@]}
    if [[ $cnt_route_commands -gt 0 ]]; then
        log_debug "Routing rules for host ${vm_name} (${#routing_commands[@]}): ${routing_commands[*]}"
        local command_string
        command_string=$(
            IFS=";"
            echo "${routing_commands[*]}"
        )
        echo "${command_string}" | run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s worker interhost route setup"
    fi

}

function bootstrap_all_nodes() {
    local KUBELET_ITERATOR=1

    while [ "$KUBELET_ITERATOR" -le "${CNT_VMS}" ]; do
        local instance="${HOSTNAME_PREFIX}${KUBELET_ITERATOR}"
        local this_vm_ip_suffix=$((STARTING_IP_SUFFIX + KUBELET_ITERATOR - 1))
        local cluster_internal_ip_range="${PRIVATE_CIDR_PREFIX}.${this_vm_ip_suffix}.0/${PRIVATE_CIDR_SUBNET_MASK}"

        install_system_libs "${instance}"
        stop_system_services "${instance}"
        install_k8s_components "${instance}"
        configure_cni_neworking "${instance}" "${cluster_internal_ip_range}"
        configure_containerd "${instance}"
        configure_kubelet "${instance}" "${cluster_internal_ip_range}"
        configure_kube_proxy "${instance}" "${STARTING_IP_PREFIX}.${this_vm_ip_suffix}"
        setup_interhost_networking "${instance}" "${KUBELET_ITERATOR}"
        start_system_services "${instance}"
        KUBELET_ITERATOR=$((KUBELET_ITERATOR + 1))
    done
}

bootstrap_all_nodes
