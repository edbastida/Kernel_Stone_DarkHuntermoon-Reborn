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

log "Preparing AnyKernel3 workspace..."
AK3_WORK="${REPO_ROOT}/out/anykernel3"
rm -rf "${AK3_WORK}"
cp -r "${AK3_DIR}" "${AK3_WORK}"
# Only overwrite anykernel.sh — do NOT touch META-INF (AnyKernel3's update-binary must stay intact)
cp "${ANYKERNEL_DIR}/anykernel.sh" "${AK3_WORK}/anykernel.sh"

log "Copying kernel image..."
IMG_BASENAME="$(basename "${KERNEL_IMAGE}")"
cp "${KERNEL_IMAGE}" "${AK3_WORK}/${IMG_BASENAME}"
ok "${IMG_BASENAME} copied"

log "Copying Realtek modules..."
MODS_DEST="${AK3_WORK}/modules/system/lib/modules"
mkdir -p "${MODS_DEST}"

REALTEK_MODS=("${MODULES_DIR}"/lib/modules/*/kernel/drivers/net/wireless/realtek/*/*.ko)
if [[ ${#REALTEK_MODS[@]} -eq 0 ]] || [[ ! -f "${REALTEK_MODS[0]}" ]]; then
    warn "No Realtek .ko modules found — continuing without them"
else
    for ko in "${REALTEK_MODS[@]}"; do
        cp "${ko}" "${MODS_DEST}/"
        log "  + $(basename "${ko}")"
    done
    ok "${#REALTEK_MODS[@]} Realtek module(s) copied"
fi

log "Detecting kernel release string..."
KERNEL_RELEASE=$(cat "${OUT_DIR}/include/config/kernel.release" 2>/dev/null || echo "${KERNEL_VERSION}")
ok "Kernel release: ${KERNEL_RELEASE}"

ZIP_NAME="nethunter-stone-${KERNEL_VERSION}-$(date +%Y%m%d).zip"
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
echo "Flash instructions:"
echo "  adb push '${ZIP_PATH}' /sdcard/Download/"
echo "  adb reboot recovery"
echo "  # In TWRP: Install → ${ZIP_NAME} → Swipe to Flash"

mark_step_done "08"
ok "Step 08 complete."
