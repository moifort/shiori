#!/usr/bin/env bash
#
# install-terraform.sh — downloads a pinned, checksum-verified terraform
# binary into infra/.bin/terraform. Idempotent: a no-op if the target
# version is already installed.
#
# This removes the need for users to install terraform system-wide before
# running `bun run bootstrap` or `bun run infra:plan|infra:apply|destroy`.

set -euo pipefail

TF_VERSION="1.10.0"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_ROOT/infra/.bin"
TF_BIN="$BIN_DIR/terraform"

log() { printf "\033[1;34m▸ %s\033[0m\n" "$*" >&2; }
fail() { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# Fast path: already installed at the right version.
if [[ -x "$TF_BIN" ]] && "$TF_BIN" version 2>/dev/null | head -n1 | grep -q "v${TF_VERSION}"; then
  exit 0
fi

command -v curl >/dev/null 2>&1   || fail "curl is required to download terraform"
command -v unzip >/dev/null 2>&1  || fail "unzip is required to extract the terraform archive"
command -v shasum >/dev/null 2>&1 || fail "shasum is required to verify the terraform checksum"

case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux"  ;;
  *) fail "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="amd64" ;;
  *) fail "unsupported arch: $(uname -m)" ;;
esac

ARCHIVE="terraform_${TF_VERSION}_${OS}_${ARCH}.zip"
SUMS="terraform_${TF_VERSION}_SHA256SUMS"
BASE_URL="https://releases.hashicorp.com/terraform/${TF_VERSION}"

log "Installing terraform ${TF_VERSION} (${OS}_${ARCH}) into infra/.bin/"

mkdir -p "$BIN_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$BASE_URL/$ARCHIVE" -o "$TMP_DIR/$ARCHIVE"
curl -fsSL "$BASE_URL/$SUMS"    -o "$TMP_DIR/$SUMS"

(cd "$TMP_DIR" && grep " $ARCHIVE\$" "$SUMS" | shasum -a 256 -c -) >/dev/null \
  || fail "terraform checksum verification failed"

unzip -q -o "$TMP_DIR/$ARCHIVE" -d "$BIN_DIR"
chmod +x "$TF_BIN"

log "terraform ${TF_VERSION} installed at $TF_BIN"
