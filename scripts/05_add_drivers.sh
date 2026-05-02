#!/usr/bin/env bash
# Step 05 — Verifica drivers Realtek (compilados out-of-tree en step 07)
#
# Diseño: los Makefiles upstream de rtl8188eus / rtl88x2bu están escritos para
# compilarse OUT-OF-TREE (`make -C $KERNEL_SRC M=$PWD modules`), no para
# integración kbuild dentro del árbol del kernel. Intentar meterlos al árbol
# rompía la resolución de includes con build dir separado (O=).
#
# Por eso step 05 ya no copia drivers al kernel tree ni toca Kconfig/Makefile.
# El kernel se compila SIN ellos, y step 07 los compila como módulos out-of-tree
# después del kernel. Los .ko quedan en sources/drivers/<drv>/ y step 08 los
# recoge desde ahí.
set -euo pipefail
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/utils.sh"

banner "Step 05 — Verify Realtek Drivers (out-of-tree)"

is_step_done "05" && { log "Step 05 already done, skipping."; exit 0; }

[[ -d "${KERNEL_DIR}/.git" ]] || die "Kernel source not found. Run step 02 first."

DRIVERS="rtl8188eus rtl88x2bu"

# Limpiar cualquier copia previa que step 05 viejo haya dejado en el árbol
# del kernel (in-tree). Si seguimos con esos archivos, el build kernel intenta
# compilarlos in-tree (vía obj-$(CONFIG_RTL...)) y falla porque sus Makefiles
# no son kbuild-friendly. Borrar y limpiar entradas en parent Kconfig/Makefile.
REALTEK_IN_TREE="${KERNEL_DIR}/drivers/net/wireless/realtek"
for drv in ${DRIVERS}; do
    if [[ -d "${REALTEK_IN_TREE}/${drv}" ]]; then
        warn "Removing stale in-tree copy: ${REALTEK_IN_TREE}/${drv}"
        rm -rf "${REALTEK_IN_TREE}/${drv}"
    fi
done
# Limpiar referencias a esos drivers en realtek/Kconfig y realtek/Makefile
if [[ -f "${REALTEK_IN_TREE}/Kconfig" ]]; then
    sed -i '/rtl8188eus\|rtl88x2bu/d' "${REALTEK_IN_TREE}/Kconfig"
fi
if [[ -f "${REALTEK_IN_TREE}/Makefile" ]]; then
    sed -i '/rtl8188eus\|rtl88x2bu/d' "${REALTEK_IN_TREE}/Makefile"
fi

log "Verifying out-of-tree driver sources..."
for drv in ${DRIVERS}; do
    src="${DRIVERS_DIR}/${drv}"
    [[ -d "${src}" ]] || die "Driver source missing: ${src} (run step 02)"
    [[ -f "${src}/Makefile" ]] || die "Driver Makefile missing: ${src}/Makefile"
    ok "Found: ${drv} → ${src}"
done

# Aplicar fixes de compat con Clang directamente al source out-of-tree
log "Applying Clang compat fixes to driver sources..."
for drv in ${DRIVERS}; do
    drv_mk="${DRIVERS_DIR}/${drv}/Makefile"
    # GCC-only flags que Clang rechaza
    sed -i '/stringop-overread/d' "${drv_mk}" 2>/dev/null || true
done
for drv_c in "${DRIVERS_DIR}"/*/core/rtw_br_ext.c; do
    [[ -f "${drv_c}" ]] || continue
    sed -i 's/#pragma GCC diagnostic ignored "-Wstringop-overread"/\/\/ pragma removed: GCC-only flag/g' "${drv_c}" 2>/dev/null || true
done
ok "Clang compat fixes applied"

# rtl8188eus usa kernel_read() que en kernels >= 5.4 está en el namespace
# privado VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver. Sin
# importarlo, el módulo carga pero falla con "Unknown symbol kernel_read".
# (rtl88x2bu upstream ya lo importa.)
RTL8188EUS_OSDEP="${DRIVERS_DIR}/rtl8188eus/os_dep/osdep_service.c"
if [[ -f "${RTL8188EUS_OSDEP}" ]] && ! grep -q "MODULE_IMPORT_NS" "${RTL8188EUS_OSDEP}"; then
    log "Patching rtl8188eus to import VFS internal namespace..."
    # Insertar después del último #include
    awk '
        BEGIN { inserted = 0; last_include = 0 }
        /^#include/ { last_include = NR }
        { lines[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == last_include && !inserted) {
                    print ""
                    print "#include <linux/module.h>"
                    print "MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver);"
                    inserted = 1
                }
            }
        }
    ' "${RTL8188EUS_OSDEP}" > "${RTL8188EUS_OSDEP}.new"
    mv "${RTL8188EUS_OSDEP}.new" "${RTL8188EUS_OSDEP}"
    ok "Added MODULE_IMPORT_NS to rtl8188eus/os_dep/osdep_service.c"
fi

mark_step_done "05"
ok "Step 05 complete (drivers will compile out-of-tree in step 07)."
