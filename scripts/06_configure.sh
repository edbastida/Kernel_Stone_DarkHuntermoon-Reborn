#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 06 — Configure Kernel"

is_step_done "06" && { log "Step 06 already done, skipping."; exit 0; }

[[ -d "${KERNEL_DIR}/.git" ]] || die "Kernel source not found. Run steps 02-05 first."
[[ -f "${NETHUNTER_CONFIG}" ]] || die "NetHunter config not found: ${NETHUNTER_CONFIG}"

export PATH="${CLANG_DIR}/bin:${PATH}"
require_cmd clang

mkdir -p "${OUT_DIR}"

# Detect kernel type: traditional (has stone/moonstone_defconfig) vs QGKI (has vendor/*.config)
QGKI_DIR="${KERNEL_DIR}/arch/arm64/configs/vendor"
KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-stone_defconfig}"

for cfg_try in stone_defconfig moonstone_defconfig; do
    if [[ -f "${KERNEL_DIR}/arch/arm64/configs/${cfg_try}" ]]; then
        KERNEL_DEFCONFIG="${cfg_try}"
        break
    fi
done

pushd "${KERNEL_DIR}" > /dev/null

if [[ -f "${KERNEL_DIR}/arch/arm64/configs/${KERNEL_DEFCONFIG}" ]]; then
    # ── Traditional defconfig path ──────────────────────────────────────────
    log "Traditional kernel detected. Using defconfig: ${KERNEL_DEFCONFIG}"

    log "Step 1: Loading defconfig..."
    make O="${OUT_DIR}" ARCH=arm64 "${KERNEL_DEFCONFIG}"
    check_error "defconfig failed"
    ok "Base defconfig loaded"

    log "Step 2: Merging NetHunter additions..."
    scripts/kconfig/merge_config.sh -m -O "${OUT_DIR}" \
        "${OUT_DIR}/.config" "${NETHUNTER_CONFIG}"
    check_error "merge_config.sh (nethunter) failed"

elif [[ -d "${QGKI_DIR}" ]]; then
    # ── QGKI / GKI kernel path ───────────────────────────────────────────────
    log "QGKI kernel detected (vendor config fragments found)"

    # Pick device config fragments — prefer moonstone, then sunstone
    DEVICE_GKI_CFG=""
    DEVICE_QGKI_CFG=""
    for dev in moonstone sunstone; do
        if [[ -f "${QGKI_DIR}/${dev}_QGKI.config" ]]; then
            DEVICE_GKI_CFG="${QGKI_DIR}/${dev}_GKI.config"
            DEVICE_QGKI_CFG="${QGKI_DIR}/${dev}_QGKI.config"
            log "Using device config: ${dev}"
            break
        fi
    done
    [[ -n "${DEVICE_QGKI_CFG}" ]] || die "No device QGKI config found in ${QGKI_DIR}"

    # Base defconfig for QGKI is 'defconfig' or 'gki_defconfig'
    BASE_CFG="defconfig"
    [[ -f "${KERNEL_DIR}/arch/arm64/configs/gki_defconfig" ]] && BASE_CFG="gki_defconfig"
    log "Step 1: Loading GKI base defconfig: ${BASE_CFG}"
    make O="${OUT_DIR}" ARCH=arm64 "${BASE_CFG}"
    check_error "GKI base defconfig failed"

    log "Step 2: Merging vendor fragments + NetHunter additions..."
    MERGE_CONFIGS=("${OUT_DIR}/.config")
    [[ -f "${DEVICE_GKI_CFG}" ]]  && MERGE_CONFIGS+=("${DEVICE_GKI_CFG}")
    [[ -f "${DEVICE_QGKI_CFG}" ]] && MERGE_CONFIGS+=("${DEVICE_QGKI_CFG}")
    MERGE_CONFIGS+=("${NETHUNTER_CONFIG}")

    scripts/kconfig/merge_config.sh -m -O "${OUT_DIR}" "${MERGE_CONFIGS[@]}"
    check_error "merge_config.sh (QGKI+nethunter) failed"

else
    die "Cannot find defconfig or QGKI vendor configs in kernel source."
fi

log "Step 3: Resolving dependencies (olddefconfig)..."
make O="${OUT_DIR}" ARCH=arm64 olddefconfig
check_error "olddefconfig failed"
ok "Config finalized"
popd > /dev/null

log "Verifying critical config options..."
CONFIG_FILE="${OUT_DIR}/.config"
check_config() {
    local opt="$1" expected="$2"
    local actual
    actual=$(grep "^${opt}=" "${CONFIG_FILE}" | cut -d= -f2 || echo "NOT_SET")
    if [[ "${actual}" != "${expected}" ]]; then
        warn "${opt}=${actual} (expected ${expected})"
    else
        ok "${opt}=${actual}"
    fi
}

check_config "CONFIG_MODULES" "y"
check_config "CONFIG_USB_CONFIGFS_F_HID" "y"
check_config "CONFIG_BT_HCIBTUSB" "y"
check_config "CONFIG_MODULE_SIG" "n"

mark_step_done "06"
ok "Step 06 complete."
