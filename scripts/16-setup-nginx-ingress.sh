#!/usr/bin/env bash
set -euo pipefail

: "${VM_RUNTIME?: VM_RUNTIME must be defined}"
: "${HOSTNAME_PREFIX?: HOSTNAME_PREFIX must be defined}"
: "${OUTPUT_DIR_CERTS?: OUTPUT_DIR_CERTS must be defined}"
: "${CSR_DIR?: CSR_DIR must be defined}"

NGINX_TLS_CERT_SECRET_NAME="ingress-nginx-default-cert"

log_info "Starting to generate TLS certificate for nginx ingress"

cfssl gencert \
  -ca="${OUTPUT_DIR_CERTS}/ca.pem" \
  -ca-key="${OUTPUT_DIR_CERTS}/ca-key.pem" \
  -config="${CSR_DIR}/ca-config.json" \
  -profile=kubernetes \
  "${CSR_DIR}/nginx-ingress-csr.json" | cfssljson -bare "${OUTPUT_DIR_CERTS}/nginx-ingress"

run_command_on_remote_host "${VM_RUNTIME}" "${HOSTNAME_PREFIX}1" "install nginx ingress" <<EOC
    export KUBECONFIG="${VM_MOUNT_LOCATION}/output/kube-configs/admin.kubeconfig"

    helm upgrade --install ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --set controller.extraArgs.v=2 \
        --set controller.extraArgs.enable-ssl-passthrough="" \
        --set controller.extraArgs.default-ssl-certificate="ingress-nginx/${NGINX_TLS_CERT_SECRET_NAME}" \
        --set controller.config.generate-request-id=true \
        --set controller.config.service-upstream=true \
        --set controller.addHeaders.X-Request-ID='\${req_id}' \

EOC

log_info "Creating default nginx ingress TLS termination secret"

run_command_on_remote_host "${VM_RUNTIME}" "${HOSTNAME_PREFIX}1" "deploy testing nginx app" <<EOC
    export KUBECONFIG="${VM_MOUNT_LOCATION}/output/kube-configs/admin.kubeconfig"
    kubectl get ns ingress-nginx || kubectl create ns ingress-nginx
    kubectl -n ingress-nginx delete secret ${NGINX_TLS_CERT_SECRET_NAME} || :
    kubectl -n ingress-nginx create secret tls ${NGINX_TLS_CERT_SECRET_NAME} \
        --key "${OUTPUT_DIR_CERTS}/nginx-ingress-key.pem" \
        --cert "${OUTPUT_DIR_CERTS}/nginx-ingress.pem"
EOC

log_info "Starting to sleep for a short amount of time to allow nginx ingress to register hooks"
sleep 30

run_command_on_remote_host "${VM_RUNTIME}" "${HOSTNAME_PREFIX}1" "deploy testing nginx app" <<EOC
    export KUBECONFIG="${VM_MOUNT_LOCATION}/output/kube-configs/admin.kubeconfig"
    kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  namespace: default
  name: nginx
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: default
  name: ingress-nginx
spec:
  tls:
    - hosts:
        - nginx.k8s.local
  rules:
  - host: nginx.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
  ingressClassName: nginx
EOF
EOC
