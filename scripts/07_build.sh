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
