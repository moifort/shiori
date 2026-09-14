#!/usr/bin/env bash
#
# teardown.sh — destroys the entire Shiori GCP/Firebase infrastructure.
# This is a destructive operation: project, Firestore data, secrets, and
# every other resource managed by Terraform are removed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infra"
TF="${INFRA_DIR}/.bin/terraform"

"$REPO_ROOT/scripts/install-terraform.sh"

cd "$INFRA_DIR"

read -rp "This will destroy the GCP project and all Firebase resources. Continue? (y/N) " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { echo "Aborted."; exit 1; }

"$TF" destroy -auto-approve

cat <<EOF

  Destroyed.

  Notes
  -----
  - The GCP project is soft-deleted; billing continues for ~30 days unless
    you fully purge it from the GCP console.
  - The remote state bucket has been removed. If you re-bootstrap, a new
    one will be created.
EOF
