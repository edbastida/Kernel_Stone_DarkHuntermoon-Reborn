#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 01 — Setup Environment"

is_step_done "01" && { log "Step 01 already done, skipping."; exit 0; }

if sudo -n true 2>/dev/null; then
    log "Updating package lists..."
    sudo apt-get update -qq
    log "Installing build dependencies..."
    sudo apt-get install -y \
        git ccache automake flex lzop bison gperf build-essential zip curl \
        zlib1g-dev g++-multilib libssl-dev bc libc6-dev-i386 lib32ncurses5-dev \
        device-tree-compiler python3 libxml2-utils bzip2 libbz2-dev \
        squashfs-tools make unzip binutils-aarch64-linux-gnu \
        libelf-dev pahole clang-17 lld-17 llvm-17
    check_error "Failed to install apt dependencies"
else
    warn "sudo not available without TTY — skipping apt-get (assuming deps pre-installed)"
fi

log "Checking for ccache..."
if command -v ccache &>/dev/null; then
    ccache --max-size=10G
    ok "ccache configured (10G max)"
fi

log "Validating cross-compile binutils..."
require_cmd aarch64-linux-gnu-ar
ok "aarch64-linux-gnu-ar: $(aarch64-linux-gnu-ar --version | head -1)"

log "Validating clang-17..."
require_cmd clang-17
ok "clang-17: $(clang-17 --version | head -1)"

log "Validating toolchain at: ${CLANG_DIR}"
if [[ -d "${CLANG_DIR}/bin" ]]; then
    export PATH="${CLANG_DIR}/bin:${PATH}"
    ok "Clang dir ready: ${CLANG_DIR}/bin"
else
    warn "Clang dir not yet created — will be set up in step 02"
fi

log "Checking Python..."
require_cmd python3
ok "Python3: $(python3 --version)"

mark_step_done "01"
ok "Step 01 complete."
