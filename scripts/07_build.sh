#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 07 — Compile Kernel"

is_step_done "07" && { log "Step 07 already done, skipping."; exit 0; }

[[ -d "${KERNEL_DIR}/.git" ]] || die "Kernel source not found. Run steps 02-06 first."
[[ -f "${OUT_DIR}/.config" ]] || die ".config not found. Run step 06 first."

export PATH="${CLANG_DIR}/bin:${PATH}"
require_cmd clang
require_cmd ld.lld

BUILD_LOG="${REPO_ROOT}/out/build.log"
mkdir -p "${OUT_DIR}" "${MODULES_DIR}" "${ZIP_DIR}"

log "Build log: ${BUILD_LOG}"
log "Using ${JOBS} parallel jobs"

# Branding: append build date to LOCALVERSION via localversion-build,
# and stamp /proc/version with deterministic user/host/timestamp.
BUILD_DATE="$(date -u +%Y%m%d)"
BUILD_TS="$(LC_ALL=C date -u)"
LOCALVERSION_FILE="${KERNEL_DIR}/localversion-build"
echo "-${BUILD_DATE}" > "${LOCALVERSION_FILE}"
trap 'rm -f "${LOCALVERSION_FILE}"' EXIT
export KBUILD_BUILD_TIMESTAMP="${BUILD_TS}"
export KBUILD_BUILD_USER="Edbastida"
export KBUILD_BUILD_HOST="DarkHunterMoon"
log "Branding: localversion += -${BUILD_DATE}, user=${KBUILD_BUILD_USER}, host=${KBUILD_BUILD_HOST}"

# kamikaonashi 5.4 hardcodes LINUX_COMPILE_BY='kami' / HOST='yourMom' in
# scripts/mkcompile_h, ignoring KBUILD_BUILD_USER/HOST. Restore upstream
# behavior so env vars take effect.
MKCH="${KERNEL_DIR}/scripts/mkcompile_h"
if grep -qE "^LINUX_COMPILE_(BY|HOST)='[^$]" "${MKCH}"; then
    log "Patching scripts/mkcompile_h to honor KBUILD_BUILD_USER/HOST..."
    sed -i \
        -e "s|^LINUX_COMPILE_BY=.*|LINUX_COMPILE_BY=\"\${KBUILD_BUILD_USER:-\$(whoami)}\"|" \
        -e "s|^LINUX_COMPILE_HOST=.*|LINUX_COMPILE_HOST=\"\${KBUILD_BUILD_HOST:-\$(hostname)}\"|" \
        "${MKCH}"
fi
# Force compile.h regeneration so the new values land in this build.
rm -f "${OUT_DIR}/include/generated/compile.h" "${OUT_DIR}/init/version.o"

log "Starting kernel build..."

BUILD_START=$(date +%s)

pushd "${KERNEL_DIR}" > /dev/null
make -j"${JOBS}" \
    O="${OUT_DIR}" \
    ARCH=arm64 \
    CC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    LD=ld.lld \
    KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP}" \
    KBUILD_BUILD_USER="${KBUILD_BUILD_USER}" \
    KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST}" \
    Image.gz modules \
    2>&1 | tee "${BUILD_LOG}"

BUILD_STATUS=${PIPESTATUS[0]}
popd > /dev/null

BUILD_END=$(date +%s)
BUILD_ELAPSED=$(( BUILD_END - BUILD_START ))
BUILD_MINS=$(( BUILD_ELAPSED / 60 ))
BUILD_SECS=$(( BUILD_ELAPSED % 60 ))

if [[ ${BUILD_STATUS} -ne 0 ]]; then
    err "Build failed after ${BUILD_MINS}m ${BUILD_SECS}s"
    err "Check the build log:"
    grep -n "error:" "${BUILD_LOG}" | head -20
    exit ${BUILD_STATUS}
fi

# Accept Image.gz-dtb (traditional) or Image.gz (GKI)
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
[[ -n "${KERNEL_IMAGE}" ]] || die "No kernel image found after build — check ${BUILD_LOG}"

ok "Kernel build successful in ${BUILD_MINS}m ${BUILD_SECS}s"
ok "Kernel image: ${KERNEL_IMAGE} ($(du -sh "${KERNEL_IMAGE}" | cut -f1))"

# ── Out-of-tree Realtek drivers ──────────────────────────────────────────────
# Los Makefiles upstream de rtl8188eus / rtl88x2bu están escritos para
# `make -C $KERNEL M=$PWD modules`. Compilarlos in-tree con kbuild rompe la
# resolución de includes (drv_types.h, halrf_psd.h, etc). Compilamos cada uno
# como módulo out-of-tree contra el kernel ya construido.
log "Compiling Realtek drivers out-of-tree..."
# El Makefile upstream de cada driver tiene
#   obj-$(CONFIG_RTL8188EU) := $(MODULE_NAME).o
# bajo `ifneq ($(KERNELRELEASE),)`. Como esos CONFIG_* no están en el .config
# del kernel (los quitamos para evitar in-tree compile), tenemos que pasarlos
# inline al sub-make para que kbuild active el target obj-m.
declare -A DRIVERS_CFG=(
    [rtl8188eus]="CONFIG_RTL8188EU=m"
    [rtl88x2bu]="CONFIG_RTL8822BU=m"
)

for drv in "${!DRIVERS_CFG[@]}"; do
    drv_src="${DRIVERS_DIR}/${drv}"
    [[ -d "${drv_src}" ]] || die "Driver source missing: ${drv_src}"
    drv_cfg_var="${DRIVERS_CFG[$drv]%%=*}"
    drv_cfg_val="${DRIVERS_CFG[$drv]#*=}"

    log "  → ${drv} (${DRIVERS_CFG[$drv]})"
    DRV_LOG="${REPO_ROOT}/out/build-${drv}.log"

    # Limpiar artefactos previos (.ko / .o de un build anterior).
    pushd "${drv_src}" > /dev/null
    make -C "${OUT_DIR}" \
        M="$(pwd)" \
        ARCH=arm64 \
        clean > /dev/null 2>&1 || true

    make -j"${JOBS}" \
        -C "${OUT_DIR}" \
        M="$(pwd)" \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        LD=ld.lld \
        "${drv_cfg_var}=${drv_cfg_val}" \
        modules \
        2>&1 | tee "${DRV_LOG}"
    DRV_STATUS=${PIPESTATUS[0]}
    popd > /dev/null

    if [[ ${DRV_STATUS} -ne 0 ]]; then
        err "Failed to build ${drv} — see ${DRV_LOG}"
        grep -n "error:" "${DRV_LOG}" | head -10
        exit ${DRV_STATUS}
    fi

    # Verificar que produjo al menos un .ko en el source dir
    KO_COUNT=$(find "${drv_src}" -maxdepth 1 -name "*.ko" -type f | wc -l)
    if [[ ${KO_COUNT} -eq 0 ]]; then
        die "${drv}: build reported success but no .ko produced in ${drv_src}"
    fi
    # Strip debug symbols — sin strip los .ko son ~350MB cada uno (vs ~3MB
    # strippeados) e inflaban el ZIP final a 200MB+.
    while IFS= read -r ko; do
        llvm-strip --strip-debug "${ko}"
    done < <(find "${drv_src}" -maxdepth 1 -name "*.ko" -type f)
    ok "  ${drv}: $(find "${drv_src}" -maxdepth 1 -name "*.ko" -type f -printf '%f (%s bytes) ')"
done

ok "All Realtek drivers built out-of-tree"

mark_step_done "07"
ok "Step 07 complete."
