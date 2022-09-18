#!/usr/bin/env bash
set -euo pipefail

: "${CSR_DIR:?CSR_DIR must be defined}"
: "${OUTPUT_DIR_CERTS:?OUTPUT_DIR_CERTS must be defined}"

log_info "Starting to generate admin user certificate and key"

cfssl gencert \
    -ca="${OUTPUT_DIR_CERTS}/ca.pem" \
    -ca-key="${OUTPUT_DIR_CERTS}/ca-key.pem" \
    -config="${CSR_DIR}/ca-config.json" \
    -profile=kubernetes \
    "${CSR_DIR}/admin-csr.json" | cfssljson -bare "${OUTPUT_DIR_CERTS}/admin"
