#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 05 — Add Realtek Drivers"

is_step_done "05" && { log "Step 05 already done, skipping."; exit 0; }

[[ -d "${KERNEL_DIR}/.git" ]] || die "Kernel source not found. Run step 02 first."
[[ -d "${DRIVERS_DIR}/rtl8188eus" ]] || die "Drivers not found. Run step 02 first."

REALTEK_IN_TREE="${KERNEL_DIR}/drivers/net/wireless/realtek"
mkdir -p "${REALTEK_IN_TREE}"

DRIVERS="rtl8188eus rtl88x2bu"

for drv in ${DRIVERS}; do
    src="${DRIVERS_DIR}/${drv}"
    dst="${REALTEK_IN_TREE}/${drv}"
    [[ -d "${src}" ]] || die "Driver source missing: ${src}"
    log "Copying ${drv}..."
    rm -rf "${dst}"
    cp -r "${src}" "${dst}"
    ok "Copied ${drv} → drivers/net/wireless/realtek/${drv}"
done

log "Wiring drivers into Kconfig..."
KCONFIG="${REALTEK_IN_TREE}/Kconfig"

# Only add entries that aren't already present
for drv in ${DRIVERS}; do
    kconfig_src="drivers/net/wireless/realtek/${drv}/Kconfig"
    if ! grep -qF "${kconfig_src}" "${KCONFIG}" 2>/dev/null; then
        echo "source \"${kconfig_src}\"" >> "${KCONFIG}"
    fi
done
ok "Kconfig updated"

log "Wiring drivers into Makefile..."
MAKEFILE="${REALTEK_IN_TREE}/Makefile"

declare -A DRV_CONFIGS=(
    [rtl8188eus]="CONFIG_RTL8188EU"
    [rtl88x2bu]="CONFIG_RTL8822BU"
)

for drv in ${DRIVERS}; do
    cfg="${DRV_CONFIGS[$drv]}"
    makefile_entry="obj-\$(${cfg})    += ${drv}/"
    if ! grep -qF "${makefile_entry}" "${MAKEFILE}" 2>/dev/null; then
        echo "${makefile_entry}" >> "${MAKEFILE}"
    fi
done
ok "Makefile updated"

log "Verifying parent Kconfig sources realtek..."
PARENT_KCONFIG="${KERNEL_DIR}/drivers/net/wireless/Kconfig"
if ! grep -q "realtek/Kconfig" "${PARENT_KCONFIG}" 2>/dev/null; then
    echo 'source "drivers/net/wireless/realtek/Kconfig"' >> "${PARENT_KCONFIG}"
    ok "Added realtek/Kconfig source to wireless/Kconfig"
fi

PARENT_MAKEFILE="${KERNEL_DIR}/drivers/net/wireless/Makefile"
if ! grep -q "realtek" "${PARENT_MAKEFILE}" 2>/dev/null; then
    echo "obj-y += realtek/" >> "${PARENT_MAKEFILE}"
    ok "Added realtek/ to wireless/Makefile"
fi

log "Applying Clang compat fixes to Realtek drivers..."
# Add include paths so drivers compile correctly when built in-tree
for drv_mk in "${REALTEK_IN_TREE}"/*/Makefile; do
    if ! grep -q 'I$(src)' "${drv_mk}" 2>/dev/null; then
        sed -i '1s/^/ccflags-y += -I$(src) -I$(src)\/include\n/' "${drv_mk}"
    fi
    # Remove GCC-only flags that Clang rejects as errors
    sed -i '/stringop-overread/d' "${drv_mk}" 2>/dev/null || true
done
# Remove GCC diagnostic pragmas that Clang rejects
for drv_c in "${REALTEK_IN_TREE}"/*/*/rtw_br_ext.c; do
    sed -i 's/#pragma GCC diagnostic ignored "-Wstringop-overread"/\/\/ pragma removed: GCC-only flag/g' "${drv_c}" 2>/dev/null || true
done
ok "Clang compat fixes applied"

mark_step_done "05"
ok "Step 05 complete."
