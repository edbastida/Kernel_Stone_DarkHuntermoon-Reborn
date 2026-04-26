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

ok "Build successful in ${BUILD_MINS}m ${BUILD_SECS}s"
ok "Kernel image: ${KERNEL_IMAGE} ($(du -sh "${KERNEL_IMAGE}" | cut -f1))"

mark_step_done "07"
ok "Step 07 complete."
