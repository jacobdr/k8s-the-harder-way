#!/usr/bin/env bash
set -euo pipefail

: "${OUTPUT_DIR:?OUTPUT_DIR must be defined}"

log_info "Starting to generate the cluster encryption key"

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

ENCRYTPION_KEY_LOCATION="${OUTPUT_DIR}/cluster-encryption-config.yaml"

cat >"${ENCRYTPION_KEY_LOCATION}" <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

log_info "Completed generating the cluster encryption key to location ${ENCRYTPION_KEY_LOCATION}"
