#!/usr/bin/env bash
set -euo pipefail

: "${CNT_VMS:?CNT_VMS must be defined}"
: "${CSR_DIR:?CSR_DIR must be defined}"
: "${OUTPUT_DIR_CERTS:?OUTPUT_DIR_CERTS must be defined}"
: "${STARTING_IP_PREFIX:?STARTING_IP_PREFIX must be defined}"
: "${STARTING_IP_SUFFIX:?STARTING_IP_SUFFIX must be defined}"
: "${HOSTNAME_PREFIX:?HOSTNAME_PREFIX must be defined}"

KUBERNETES_PUBLIC_ADDRESS=()

###

log_info "Starting to generate the k8s API server certificates and keys"
log_debug "STARTING_IP_SUFFIX=${STARTING_IP_SUFFIX}"

###

ITERATOR=1

while [ "$ITERATOR" -le "${CNT_VMS}" ]; do
  KUBERNETES_PUBLIC_ADDRESS+=("${STARTING_IP_PREFIX}.${STARTING_IP_SUFFIX}")
  STARTING_IP_SUFFIX=$((STARTING_IP_SUFFIX + 1))
  ITERATOR=$((ITERATOR + 1))
done

PUBLIC_TRANSLATED_IPS="$(
  export IFS=,
  echo "${KUBERNETES_PUBLIC_ADDRESS[*]}"
)"

log_info "Public IP addresses for k8s-apiserver certificates: ${PUBLIC_TRANSLATED_IPS}"

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

log_debug "Using CSR_DIR value of ${CSR_DIR}"

cat >"${CSR_DIR}/kubernetes-csr.json" <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "JDR DEBUG CSR_DIR issue"
ls -lh "${CSR_DIR}"
cat "${CSR_DIR}"/*

# TODO: Add hostnames for HA for the ingress IPs
cfssl gencert \
  -ca="${OUTPUT_DIR_CERTS}/ca.pem" \
  -ca-key="${OUTPUT_DIR_CERTS}/ca-key.pem" \
  -config="${CSR_DIR}/ca-config.json" \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,"${PUBLIC_TRANSLATED_IPS}",127.0.0.1,"${KUBERNETES_HOSTNAMES}" \
  -profile=kubernetes \
  "${CSR_DIR}/kubernetes-csr.json" | cfssljson -bare "${OUTPUT_DIR_CERTS}/kubernetes"

openssl req -in "${OUTPUT_DIR_CERTS}/kubernetes.csr" -noout -text

log_info "Completed genearting the k8s API server certificates and keys"
