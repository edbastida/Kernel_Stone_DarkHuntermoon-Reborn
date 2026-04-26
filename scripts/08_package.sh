#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 08 — Package Flasheable ZIP"

is_step_done "08" && { log "Step 08 already done, skipping."; exit 0; }

KERNEL_IMAGE=""
for img_try in \
    "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" \
    "${OUT_DIR}/arch/arm64/boot/Image.gz" \
    "${OUT_DIR}/arch/arm64/boot/Image"; do
    if [[ -f "${img_try}" ]]; then
        KERNEL_IMAGE="${img_try}"
        break
    fi
done
[[ -n "${KERNEL_IMAGE}" ]] || die "No kernel image found. Run step 07 first."
log "Kernel image: ${KERNEL_IMAGE}"

export PATH="${CLANG_DIR}/bin:${PATH}"

log "Installing kernel modules..."
pushd "${KERNEL_DIR}" > /dev/null
make -j"${JOBS}" \
    O="${OUT_DIR}" \
    ARCH=arm64 \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    STRIP=llvm-strip \
    INSTALL_MOD_PATH="${MODULES_DIR}" \
    modules_install
check_error "modules_install failed"
popd > /dev/null
ok "Modules installed to ${MODULES_DIR}"

log "Preparing AnyKernel3 workspace (KSU mode: ${KSU})..."
AK3_WORK="${REPO_ROOT}/out/anykernel3"
rm -rf "${AK3_WORK}"
cp -r "${AK3_DIR}" "${AK3_WORK}"
# Pick the right anykernel.sh variant for the active KSU mode.
case "${KSU}" in
    ksunext) AK_VARIANT="${ANYKERNEL_DIR}/anykernel.ksunext.sh" ;;
    none)    AK_VARIANT="${ANYKERNEL_DIR}/anykernel.magisk.sh" ;;
esac
[[ -f "${AK_VARIANT}" ]] || die "Missing anykernel variant: ${AK_VARIANT}"
cp "${AK_VARIANT}" "${AK3_WORK}/anykernel.sh"
log "Using anykernel variant: $(basename "${AK_VARIANT}")"

log "Copying kernel image..."
IMG_BASENAME="$(basename "${KERNEL_IMAGE}")"
cp "${KERNEL_IMAGE}" "${AK3_WORK}/${IMG_BASENAME}"
ok "${IMG_BASENAME} copied"

log "Detecting kernel release string..."
KERNEL_RELEASE=$(cat "${OUT_DIR}/include/config/kernel.release" 2>/dev/null || echo "${KERNEL_VERSION}")
ok "Kernel release: ${KERNEL_RELEASE}"

BUILD_DATE="$(date +%Y%m%d)"

REALTEK_MODS=("${MODULES_DIR}"/lib/modules/*/kernel/drivers/net/wireless/realtek/*/*.ko)
HAVE_MODS=0
[[ ${#REALTEK_MODS[@]} -gt 0 && -f "${REALTEK_MODS[0]}" ]] && HAVE_MODS=1

if [[ "${KSU}" == "ksunext" ]]; then
    log "Staging Realtek modules as KSU Next module (in-ZIP auto-install)..."
    MOD_STAGE="${AK3_WORK}/ksu_module/system/lib/modules"
    rm -rf "${AK3_WORK}/ksu_module"
    mkdir -p "${MOD_STAGE}"

    if [[ ${HAVE_MODS} -eq 1 ]]; then
        for ko in "${REALTEK_MODS[@]}"; do
            cp "${ko}" "${MOD_STAGE}/"
            log "  + $(basename "${ko}")"
        done
        ok "${#REALTEK_MODS[@]} Realtek module(s) staged"
    else
        warn "No Realtek .ko modules found — continuing without them"
    fi

    cat > "${AK3_WORK}/ksu_module/module.prop" << EOF
id=nethunter-realtek-drivers
name=NetHunter Realtek Drivers
version=v1.0-${BUILD_DATE}
versionCode=${BUILD_DATE}
author=edbastida
description=RTL8188EU (TL-WN722N v2/v3) and RTL88x2BU drivers for NetHunter — bundled with kernel ZIP
EOF

    cat > "${AK3_WORK}/ksu_module/service.sh" << 'EOF'
#!/system/bin/sh
MODDIR=${0%/*}
LOG=/data/local/tmp/realtek_drivers.log
echo "[$(date)] NetHunter Realtek service.sh start" >> "$LOG"
sleep 8
for ko in "$MODDIR"/system/lib/modules/*.ko; do
    [ -f "$ko" ] || continue
    mod=$(basename "$ko" .ko)
    if grep -q "^${mod} " /proc/modules 2>/dev/null; then
        echo "  ${mod}: already loaded" >> "$LOG"
        continue
    fi
    if insmod "$ko" 2>>"$LOG"; then
        echo "  ${mod}: loaded" >> "$LOG"
    else
        echo "  ${mod}: insmod FAILED" >> "$LOG"
    fi
done
EOF
    chmod +x "${AK3_WORK}/ksu_module/service.sh"

    KSU_VARIANT="KsuNext"

else  # KSU=none — Magisk path: drop modules into AnyKernel3's standard slot
    log "Staging Realtek modules into AnyKernel3 standard path (Magisk-systemless)..."
    MOD_STAGE="${AK3_WORK}/modules/system/lib/modules"
    mkdir -p "${MOD_STAGE}"
    rm -rf "${AK3_WORK}/ksu_module"

    if [[ ${HAVE_MODS} -eq 1 ]]; then
        for ko in "${REALTEK_MODS[@]}"; do
            cp "${ko}" "${MOD_STAGE}/"
            log "  + $(basename "${ko}")"
        done
        ok "${#REALTEK_MODS[@]} Realtek module(s) staged"
    else
        warn "No Realtek .ko modules found — continuing without them"
    fi

    KSU_VARIANT="NonKsu"
fi
log "KSU variant: ${KSU_VARIANT}"

ZIP_NAME="${KERNEL_NAME}-By_${KERNEL_AUTHOR}.NH_${ROM_TARGET}.${KSU_VARIANT}.${BUILD_DATE}.zip"
ZIP_PATH="${ZIP_DIR}/${ZIP_NAME}"
mkdir -p "${ZIP_DIR}"

log "Creating ZIP: ${ZIP_NAME}..."
pushd "${AK3_WORK}" > /dev/null
zip -r9 "${ZIP_PATH}" . \
    -x ".git*" \
    -x "*.placeholder" \
    -x "*.md" \
    -x "LICENSE"
check_error "zip failed"
popd > /dev/null

ok "ZIP created: ${ZIP_PATH} ($(du -sh "${ZIP_PATH}" | cut -f1))"

echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  DONE: ${ZIP_NAME}${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo "Flash kernel:"
echo "  TWRP → Install → ${ZIP_NAME}"
echo ""
if [[ "${KSU}" == "ksunext" ]]; then
    echo "Realtek drivers are auto-installed as KSU Next module on first boot."
    echo "Verify after reboot:"
    echo "  adb shell ls /data/adb/modules/nethunter-realtek-drivers/"
    echo "  adb shell lsmod | grep -E '8188eu|88x2bu'"
else
    echo "Root: install Magisk separately (TWRP → Install Magisk.zip, or"
    echo "       Magisk Manager → Install → Patch boot image)."
    echo "After Magisk is active, modules are loaded by Magisk-systemless."
    echo "Verify after reboot:"
    echo "  adb shell lsmod | grep -E '8188eu|88x2bu'"
fi

mark_step_done "08"
ok "Step 08 complete."
