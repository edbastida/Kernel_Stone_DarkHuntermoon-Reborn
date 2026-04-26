#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 04 — Integrate / Remove KernelSU (mode: ${KSU})"

is_step_done "04" && { log "Step 04 already done, skipping."; exit 0; }

[[ -d "${KERNEL_DIR}/.git" ]] || die "Kernel source not found. Run step 02 first."

if [[ "${KSU}" == "ksunext" ]]; then
    if [[ -d "${KERNEL_DIR}/KernelSU-Next" || -L "${KERNEL_DIR}/drivers/kernelsu" ]]; then
        log "KernelSU-Next already in kernel tree, skipping setup."
    else
        log "Running KSU Next setup script (legacy branch for 5.4 compat)..."
        # 'legacy' branch: pgtable.h is conditional (>= 5.10), safe for 5.4
        pushd "${KERNEL_DIR}" > /dev/null
        curl -LSsf "${KSU_SETUP_URL}" | bash -s legacy
        check_error "KSU setup script failed"
        popd > /dev/null
    fi

    log "Verifying KSU integration..."
    [[ -L "${KERNEL_DIR}/drivers/kernelsu" || -d "${KERNEL_DIR}/KernelSU-Next" ]] \
        || die "KernelSU not found in kernel tree after setup"
    grep -qE "kernelsu|KernelSU" "${KERNEL_DIR}/drivers/Makefile" || \
        die "KSU not wired into drivers/Makefile"
    grep -qE "kernelsu|KernelSU" "${KERNEL_DIR}/drivers/Kconfig" || \
        die "KSU not wired into drivers/Kconfig"

    ok "KernelSU Next (legacy) integrated."

else  # KSU=none — strip any prior KSU integration so kernel builds clean for Magisk
    log "KSU=none: removing any prior KernelSU integration..."

    [[ -L "${KERNEL_DIR}/drivers/kernelsu" ]] && rm -f "${KERNEL_DIR}/drivers/kernelsu"
    [[ -d "${KERNEL_DIR}/KernelSU-Next"    ]] && rm -rf "${KERNEL_DIR}/KernelSU-Next"
    [[ -d "${KERNEL_DIR}/KernelSU"         ]] && rm -rf "${KERNEL_DIR}/KernelSU"

    sed -i '/kernelsu\|KernelSU/d' "${KERNEL_DIR}/drivers/Makefile" 2>/dev/null || true
    sed -i '/kernelsu\|KernelSU/d' "${KERNEL_DIR}/drivers/Kconfig"  2>/dev/null || true

    ok "KSU stripped from kernel tree. Root will be provided by Magisk after flash."
fi

mark_step_done "04"
ok "Step 04 complete."
