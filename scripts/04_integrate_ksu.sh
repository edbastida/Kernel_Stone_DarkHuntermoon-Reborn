#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 04 — KernelSU (disabled — using Magisk)"

is_step_done "04" && { log "Step 04 already done, skipping."; exit 0; }

[[ -d "${KERNEL_DIR}/.git" ]] || die "Kernel source not found. Run step 02 first."

# Remove any previously installed KSU artifacts
if [[ -L "${KERNEL_DIR}/drivers/kernelsu" ]]; then
    log "Removing drivers/kernelsu symlink..."
    rm -f "${KERNEL_DIR}/drivers/kernelsu"
fi
if [[ -d "${KERNEL_DIR}/KernelSU-Next" ]]; then
    log "Removing KernelSU-Next directory..."
    rm -rf "${KERNEL_DIR}/KernelSU-Next"
fi
if [[ -d "${KERNEL_DIR}/KernelSU" ]]; then
    log "Removing KernelSU directory..."
    rm -rf "${KERNEL_DIR}/KernelSU"
fi

# Remove KSU entries from drivers/Makefile and drivers/Kconfig
sed -i '/kernelsu\|KernelSU/d' "${KERNEL_DIR}/drivers/Makefile" 2>/dev/null || true
sed -i '/kernelsu\|KernelSU/d' "${KERNEL_DIR}/drivers/Kconfig"  2>/dev/null || true

# Remove pgtable compat shim if we added it
rm -f "${KERNEL_DIR}/include/linux/pgtable.h"

ok "KernelSU removed. Root will be provided by Magisk."

mark_step_done "04"
ok "Step 04 complete."
