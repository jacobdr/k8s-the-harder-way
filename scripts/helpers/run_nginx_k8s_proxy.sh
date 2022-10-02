#!/usr/bin/env bash
set -euo pipefail

HELPERS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT=$(cd "${HELPERS_DIR}/../.." && pwd)

# shellcheck source=../-1-environment.sh
source "${PROJECT_ROOT}/scripts/-1-environment.sh"
# shellcheck source=./networking.sh
source "${HELPERS_DIR}/networking.sh"
# shellcheck source=./logging.sh
source "${HELPERS_DIR}/logging.sh"
# shellcheck source=./remote_command.sh
source "${HELPERS_DIR}/remote_command.sh"

export KUBECONFIG="${PROJECT_ROOT}/output/kube-configs/admin.kubeconfig"

function get_ingress_ip_address() {
    run_command_on_remote_host "${VM_RUNTIME}" "vm1" "get nginx-ingress loadbalancer IP address" <<EOF
    export KUBECONFIG=${KUBECONFIG}
    kubectl get services --namespace ingress-nginx ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
EOF
}

export -f get_ingress_ip_address

function generate_nginx_configuration() {
    local ingress_external_ip
    ingress_external_ip=$(get_ingress_ip_address)
    log_info "Ingress IP address candidate: ${ingress_external_ip}"

    if ! [[ ${ingress_external_ip} =~ (.+)\.(.+)\.(.+)\.(.+) ]]; then
        log_error "Failed to find ingress IP address for the nginx-ingress. Got ${ingress_external_ip}"
        log_error "Something is wrong and we won't be able to proxy traffic into the cluster. Exiting"
        exit 1
    fi

    log_info "Resolved ingress IP address to: ${ingress_external_ip}"

    tee "${PROJECT_ROOT}/nginx.conf" <<EOF
error_log stderr;

events {
}

http {
    log_format main '\$remote_addr - \$remote_user [\$time_local] \$status '
    '"\$request" \$body_bytes_sent "\$http_referer" '
    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /dev/stdout main;
}

stream {
    upstream k8s_api_servers {
        server vm1:6443;
        server vm2:6443;
        server vm3:6443;
    }

    upstream k8s_ingress_non_tls_traffic {
        server ${ingress_external_ip}:80;
    }

    upstream k8s_ingress_tls_traffic {
        server ${ingress_external_ip}:443;
    }

    log_format basic '\$remote_addr [\$time_local] '
    '\$protocol \$status \$bytes_sent \$bytes_received '
    '\$session_time "\$upstream_addr" '
    '"\$upstream_bytes_sent" "\$upstream_bytes_received" "\$upstream_connect_time"';

    access_log /dev/stdout basic;

    server {
        listen 6443;
        proxy_pass k8s_api_servers;
        proxy_next_upstream on;
    }

    server {
        listen 80;
        proxy_pass k8s_ingress_non_tls_traffic;
        proxy_next_upstream on;
    }
    server {
        listen 443;
        proxy_pass k8s_ingress_tls_traffic;
        proxy_next_upstream on;
    }
}
EOF
}

function main() {
    docker rm -f k8s-nginx
    generate_nginx_configuration

    docker run -it \
        --name k8s-nginx \
        -p 443:443 \
        -p 80:80 \
        -p 6443:6443 \
        -v "${PROJECT_ROOT}/nginx.conf:/etc/nginx/nginx.conf:ro" \
        -v "${PROJECT_ROOT}/output/certificates:/certs:ro" \
        --link vm1 --link vm2 --link vm3 \
        nginx:alpine
}

main
