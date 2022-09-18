#!/usr/bin/env bash
set -euo pipefail

: "${STARTING_IP_PREFIX:?STARTING_IP_PREFIX: must be defined}"
: "${HOSTNAME_PREFIX:?HOSTNAME_PREFIX must be defined}"
: "${VM_MOUNT_LOCATION:?VM_MOUNT_LOCATION: must be defined}"
: "${K8S_VERSION:?K8S_VERSION: must be defined}"
: "${CNT_VMS:?CNT_VMS: must be defined}"
: "${KUBE_CONFIG_DIR:?KUBE_CONFIG_DIR: must be defined}"
: "${CPU_ARCH:?CPU_ARCH: must be defined}"
: "${VM_MOUNT_LOCATION:?CPU_ARCH: must be defined}"
: "${DOWNLOAD_CACHE_DIR:?DOWNLOAD_CACHE_DIR: must be defined}"

function download_binaries() {
    local vm_name=${1:?Expected the VM name to be supplied as the first param}
    local base_url="https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux"
    local BINARY_COMPONNENTS=(
        "kube-apiserver"
        "kube-controller-manager"
        "kube-scheduler"
        "kubectl"
    )

    log_info "Starting to stop running k8s components on ${vm_name}"
    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "stop k8s control plane services" <<EOF
        sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler || log_info "No need to stop services"
EOF

    log_info "Starting to install k8s control plane binaries"
    for component in "${BINARY_COMPONNENTS[@]}"; do
        local install_url="${base_url}/${CPU_ARCH}/${component}"
        local binary_name
        binary_name="$(basename "${install_url}")"

        run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "install k8s component ${binary_name}" <<EOF
        export STARTING_IP_PREFIX=${STARTING_IP_PREFIX}
        export HOSTNAME_PREFIX=${HOSTNAME_PREFIX}
        export VM_MOUNT_LOCATION=${VM_MOUNT_LOCATION}
        export K8S_VERSION=${K8S_VERSION}
        export CNT_VMS=${CNT_VMS}
        export KUBE_CONFIG_DIR=${KUBE_CONFIG_DIR}

        mkdir -p ${DOWNLOAD_CACHE_DIR}
        cd ${DOWNLOAD_CACHE_DIR}

        if [[ -f "${binary_name}" ]]; then
            log_info "Binary ${binary_name} found in the mount cache"
        else
            log_debug "Need to fetch control plane binary -- installed binaries are \$(ls . | xargs)"
        fi

        if ! [[ -f "${binary_name}" ]] ; then
            log_info "Starting to download binary ${binary_name}"
            curl --fail -L -O "${install_url}"
            chmod +x "${component}"
            sudo cp "${component}" /usr/local/bin/
        fi

EOF
    done
    log_info "Completed downloading k8s control plane binaries"
}

function configure_k8s() {
    local vm_name=${1:?Expected the VM name to be supplied as the first param}
    local control_plane_node_public_ip=${2:? Must supply node public ip address as the second parameter}
    local etcd_addresses=${3:? Must supply etcd addresses as the third parameter}

    log_info "Starting to setup kube-apiserver kube-controller-manager kube-scheduler on ${vm_name}"

    run_command_on_remote_host "${VM_RUNTIME}" "${vm_name}" "k8s control plane configuration" <<EOC
        export STARTING_IP_PREFIX=${STARTING_IP_PREFIX}
        export HOSTNAME_PREFIX=${HOSTNAME_PREFIX}
        export VM_MOUNT_LOCATION=${VM_MOUNT_LOCATION}
        export K8S_VERSION=${K8S_VERSION}
        export CNT_VMS=${CNT_VMS}
        export KUBE_CONFIG_DIR=${KUBE_CONFIG_DIR}

    sudo rm -rf /var/lib/kubernetes/
    sudo mkdir -p /var/lib/kubernetes/

    log_info "Copying kube apiserver certificates and CA root certs to /var/lib/kubernetes"
    sudo cp \
        "${VM_MOUNT_LOCATION}/output/certificates/ca.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/ca-key.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/kubernetes-key.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/kubernetes.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/service-account-key.pem" \
        "${VM_MOUNT_LOCATION}/output/certificates/service-account.pem" \
        "${VM_MOUNT_LOCATION}/output/cluster-encryption-config.yaml" \
        /var/lib/kubernetes/

    ### API Server
    cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${control_plane_node_public_ip} \\
  --allow-privileged=true \\
  --apiserver-count=${CNT_VMS} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${etcd_addresses} \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/cluster-encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://0.0.0.0:6443 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --requestheader-client-ca-file=/var/lib/kubernetes/ca.pem \\
  --feature-gates=EphemeralContainers=true \\
  --v=3
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    ### Controller Manager
    log_info "Copying kube controller manager kubeconfig from ${VM_MOUNT_LOCATION}/kube-configs to /var/lib/kubernetes"
    sudo cp "${VM_MOUNT_LOCATION}/output/kube-configs/kube-controller-manager.kubeconfig" /var/lib/kubernetes/

    cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=3
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    ### Kube Scheduler
    log_info "Copying kube scheduler kubeconfig to /var/lib/kubernetes"
    sudo cp "${VM_MOUNT_LOCATION}/output/kube-configs/kube-scheduler.kubeconfig" /var/lib/kubernetes/
    sudo mkdir -p /etc/kubernetes/config

    cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
    apiVersion: kubescheduler.config.k8s.io/v1beta1
    kind: KubeSchedulerConfiguration
    clientConnection:
        kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
    leaderElection:
        leaderElect: true
EOF

    cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
    [Unit]
    Description=Kubernetes Scheduler
    Documentation=https://github.com/kubernetes/kubernetes

    [Service]
    ExecStart=/usr/local/bin/kube-scheduler \\
      --config=/etc/kubernetes/config/kube-scheduler.yaml \\
      --v=3
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
    sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler
    sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
EOC
}

function install_on_single_node() {
    : "${1:? Must supply the VM number as the first param}"
    local vm_number="${1}"
    local instance="${HOSTNAME_PREFIX}${vm_number}"
    local vm_iterator=1
    local this_vm_ip_suffix=$((STARTING_IP_SUFFIX + vm_number - 1))
    local etcd_ip_suffix=${STARTING_IP_SUFFIX}

    INTERNAL_IP="${STARTING_IP_PREFIX}.${this_vm_ip_suffix}"

    while [ "$vm_iterator" -le "${CNT_VMS}" ]; do
        ETCD_CLIENT_PUBLIC_ADDRESS+=("https://${STARTING_IP_PREFIX}.${etcd_ip_suffix}:2379")
        etcd_ip_suffix=$((etcd_ip_suffix + 1))
        vm_iterator=$((vm_iterator + 1))
    done

    ETCD_PUBLIC_IP_STR="$(
        export IFS=,
        echo "${ETCD_CLIENT_PUBLIC_ADDRESS[*]}"
    )"

    download_binaries "${instance}"
    configure_k8s "${instance}" "${INTERNAL_IP}" "${ETCD_PUBLIC_IP_STR}"
}

function grant_log_and_port_forward_access_to_apiserver_user() {
    : "${1:? Must supply the VM number as the first param}"
    log_info "Starting to grant logging access to the k8s k8s api server user"
    local vm_number="${1}"
    run_command_on_remote_host "${VM_RUNTIME}" "${HOSTNAME_PREFIX}${vm_number}" "k8s grant log access to k8s api server" <<EOC
export KUBECONFIG="${VM_MOUNT_LOCATION}/output/kube-configs/admin.kubeconfig"
kubectl apply -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-apiserver-logs-and-port-forward
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - pods/logs
  - pods/port-forward
  - nodes/proxy
  verbs:
  - get
  - list
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-apiserver-logs-and-port-forward
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-apiserver-logs-and-port-forward
subjects:
- kind: User
  name: kubernetes
---
EOF
EOC
}

function main() {
    local vm_iterator=1
    while [ "$vm_iterator" -le "${CNT_VMS}" ]; do
        install_on_single_node "${vm_iterator}"
        vm_iterator=$((vm_iterator + 1))
    done

    log_info "Sleeping for a short period of time to let k8s api servers start up"
    sleep 5
    grant_log_and_port_forward_access_to_apiserver_user "1"
}

main
