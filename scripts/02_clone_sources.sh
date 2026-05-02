#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 02 — Clone Sources"

is_step_done "02" && [[ -n "${SKIP_CLONE:-}" ]] && { log "Step 02 already done, skipping."; exit 0; }

clone_or_skip() {
    local dest="$1" url="$2" branch="${3:-}"
    if [[ -d "${dest}/.git" ]] && [[ -n "${SKIP_CLONE:-}" ]]; then
        log "Skipping (SKIP_CLONE set): ${dest}"
        return 0
    fi
    if [[ -d "${dest}/.git" ]]; then
        warn "Destination exists, removing: ${dest}"
        rm -rf "${dest}"
    fi
    local branch_args=()
    [[ -n "${branch}" ]] && branch_args=(-b "${branch}")
    log "Cloning ${url} ${branch:+(branch: $branch)}..."
    git clone --depth=1 "${branch_args[@]}" "${url}" "${dest}"
    check_error "Failed to clone ${url}"
    ok "Cloned: $(basename "${dest}")"
}

log "--- Clang 17 ---"
if command -v clang-17 &>/dev/null; then
    log "clang-17 found in system PATH — creating symlink tree at ${CLANG_DIR}/bin"
    mkdir -p "${CLANG_DIR}/bin"
    for tool in clang clang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-strip llvm-readelf llvm-size; do
        sys_bin="/usr/bin/${tool}-17"
        link="${CLANG_DIR}/bin/${tool}"
        if [[ -f "${sys_bin}" ]]; then
            ln -sf "${sys_bin}" "${link}"
        elif [[ -f "/usr/bin/${tool}" ]]; then
            ln -sf "/usr/bin/${tool}" "${link}"
        fi
    done
    ln -sf "$(which clang-17)" "${CLANG_DIR}/bin/clang-17"
    ok "Clang 17 symlink tree ready: ${CLANG_DIR}/bin"
else
    clone_or_skip "${CLANG_DIR}" "${CLANG_REPO}" "${CLANG_BRANCH}"
fi

log "--- Kernel source ---"
if [[ -d "${KERNEL_DIR}/.git" ]] && [[ -n "${SKIP_CLONE:-}" ]]; then
    log "Skipping kernel clone (SKIP_CLONE set)"
else
    if [[ -d "${KERNEL_DIR}/.git" ]]; then
        warn "Removing existing kernel dir — invalidating downstream steps 03-08"
        rm -rf "${KERNEL_DIR}"
        # Reclonar el kernel borra los patches aplicados, los drivers Realtek
        # copiados al árbol y la integración KSU. Sin invalidar estos markers,
        # los steps se saltan y el kernel se compila incompleto (modulos
        # Realtek faltantes → CRC mismatch al cargar en boot).
        rm -f "$(step_done_file 03)" "$(step_done_file 04)" \
              "$(step_done_file 05)" "$(step_done_file 06)" \
              "$(step_done_file 07)" "$(step_done_file 08)"
    fi
    kernel_cloned=0
    for branch_try in "${KERNEL_BRANCH}" main master; do
        log "Trying kernel branch: ${branch_try}..."
        if git clone --depth=1 -b "${branch_try}" "${KERNEL_REPO}" "${KERNEL_DIR}" 2>&1; then
            # Accept: stone/moonstone_defconfig (traditional) OR vendor/moonstone_QGKI.config (GKI)
            found_cfg=""
            for cfg_try in stone_defconfig moonstone_defconfig; do
                if [[ -f "${KERNEL_DIR}/arch/arm64/configs/${cfg_try}" ]]; then
                    found_cfg="${cfg_try}"
                    break
                fi
            done
            qgki_ok=0
            [[ -f "${KERNEL_DIR}/arch/arm64/configs/vendor/moonstone_QGKI.config" ]] && qgki_ok=1
            [[ -f "${KERNEL_DIR}/arch/arm64/configs/vendor/sunstone_QGKI.config" ]] && qgki_ok=1

            if [[ -n "${found_cfg}" ]]; then
                ok "Kernel cloned on branch: ${branch_try} (defconfig: ${found_cfg})"
                kernel_cloned=1
                break
            elif [[ ${qgki_ok} -eq 1 ]]; then
                ok "Kernel cloned on branch: ${branch_try} (QGKI build system)"
                kernel_cloned=1
                break
            else
                warn "Branch ${branch_try} has no stone/moonstone config, trying next..."
                rm -rf "${KERNEL_DIR}"
            fi
        else
            warn "Branch ${branch_try} not found, trying next..."
            rm -rf "${KERNEL_DIR}" 2>/dev/null || true
        fi
    done
    [[ ${kernel_cloned} -eq 1 ]] || die "No usable stone/moonstone kernel config found on any branch."
fi
ok "Kernel source ready. Defconfig: arch/arm64/configs/${KERNEL_DEFCONFIG}"

log "--- AnyKernel3 ---"
clone_or_skip "${AK3_DIR}" "${AK3_REPO}"

log "--- Realtek drivers ---"
for drv in rtl8188eus rtl88x2bu rtl8192eu rtl8812au rtl8188fu; do
    url="${DRIVER_REPOS[$drv]}"
    branch="${DRIVER_BRANCHES[$drv]:-}"
    clone_or_skip "${DRIVERS_DIR}/${drv}" "${url}" "${branch}"
done

mark_step_done "02"
ok "Step 02 complete."
