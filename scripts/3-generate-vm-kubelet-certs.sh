#!/usr/bin/env bash
set -euo pipefail

: "${CNT_VMS:?CNT_VMS must be defined}"
: "${CSR_DIR:?CSR_DIR must be defined}"
: "${OUTPUT_DIR_CERTS:?OUTPUT_DIR_CERTS must be defined}"
: "${STARTING_IP_PREFIX:?STARTING_IP_PREFIX must be defined}"
: "${STARTING_IP_SUFFIX:?STARTING_IP_SUFFIX must be defined}"
: "${HOSTNAME_PREFIX:?HOSTNAME_PREFIX must be defined}"

function generate_kubelet_cert() {
  : "${1:? Must supply the vm number as the first arg}"
  local vm_number="${1}"
  local instance="${HOSTNAME_PREFIX}${vm_number}"
  local vm_csr_file="${CSR_DIR}/${instance}-csr.json"
  cat >"${vm_csr_file}" <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  EXTERNAL_IP="${STARTING_IP_PREFIX}.${STARTING_IP_SUFFIX}"
  INTERNAL_IP="${STARTING_IP_PREFIX}.${STARTING_IP_SUFFIX}"

  local kubelet_cert_hosts="${instance},${EXTERNAL_IP},${INTERNAL_IP}"
  local output_location="${OUTPUT_DIR_CERTS}/${instance}"

  log_info "Generating kubelet certs ${ITERATOR} of ${CNT_VMS} -- kubelet_cert_hosts=${kubelet_cert_hosts} output_location=${output_location}"

  cfssl gencert \
    -ca="${OUTPUT_DIR_CERTS}/ca.pem" \
    -ca-key="${OUTPUT_DIR_CERTS}/ca-key.pem" \
    -config="${CSR_DIR}/ca-config.json" \
    -hostname="${kubelet_cert_hosts}" \
    -profile=kubernetes \
    "${vm_csr_file}" | cfssljson -bare "${output_location}"

  STARTING_IP_SUFFIX=$((STARTING_IP_SUFFIX + 1))
}

ITERATOR=1

log_info "Starting to generate kubelet certificates and keys"

while [ "$ITERATOR" -le "${CNT_VMS}" ]; do
  generate_kubelet_cert ${ITERATOR}
  ITERATOR=$((ITERATOR + 1))
done

log_info "Completed generating kubelet certificates and keys"
