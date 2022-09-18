#!/usr/bin/env bash
set -euo pipefail

: "${CSR_DIR:?CSR_DIR must be defined}"
: "${OUTPUT_DIR_CERTS:?OUTPUT_DIR_CERTS must be defined}"

log_info "Starting to generate Root CA certifacates and key"

# Generate the CA
cfssl gencert -initca "${CSR_DIR}/ca-csr.json" | cfssljson -bare "${OUTPUT_DIR_CERTS}/ca"
