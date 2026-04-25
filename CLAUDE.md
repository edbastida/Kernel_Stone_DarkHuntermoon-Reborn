# nethunter-stone

Kernel NetHunter para POCO X5 5G (stone/moonstone) / Redmi Note 12 5G (sunstone).
SoC: SM6375 (Snapdragon 695 5G). Kernel: 5.4.x. Android: 16. ROM: Matrixx.

## Comandos

- `bash build.sh` — Build completo end-to-end (Steps 01–08)
- `bash build.sh --step=configure` — Solo Step 06 (configurar kernel)
- `bash build.sh --step=compile` — Solo Step 07 (compilar)
- `bash build.sh --step=package` — Steps 07–08 (módulos + ZIP)
- `bash build.sh --clean` — Borra .done_* para forzar re-ejecución de todos los pasos
- `bash scripts/07_build.sh 2>&1 | tee out/build.log` — Build con log explícito

## Stack

Clang 17 + GNU binutils aarch64-linux-gnu + Bash + Docker ubuntu:22.04 + AnyKernel3

## Architecture

### Directorios clave
- `scripts/` — Scripts 01–08 ejecutados en orden; cada uno es una etapa del build
- `scripts/lib/config.sh` — Fuente única de variables globales y rutas — editar aquí
- `scripts/lib/utils.sh` — log(), die(), check_error(), banners
- `patches/` — Patches organizados: nethunter/, qcacld/, mtk/ — aplicar en ese orden
- `config/stone_nethunter.config` — ADICIONES al defconfig, no standalone
- `anykernel/` — anykernel.sh y META-INF para el ZIP flasheable
- `sources/` — Repos clonados (gitignored — no commitear)
- `out/` — Artefactos de build (gitignored — no commitear)

### Flujo de build
01_setup_env → 02_clone_sources → 03_apply_patches → 04_integrate_ksu →
05_add_drivers → 06_configure → 07_build → 08_package

### Idempotencia
Cada script verifica con `is_step_done "<step>"` si ya corrió.
`bash build.sh --clean` resetea todos los marcadores para re-ejecutar desde cero.

### Patrones clave
- Patches se aplican con `git apply`, nunca con `patch -p1`
- Drivers Realtek van en `drivers/net/wireless/realtek/<nombre>/`
- stone_nethunter.config se mergea con `merge_config.sh`, NO reemplaza el defconfig
- Output final: `out/zip/nethunter-stone-5.4.302-<fecha>.zip`
- Si build falla: `grep -n "error:" out/build.log` — no adivinar

## Variables de entorno

| Variable | Descripción | Default |
|---|---|---|
| `KERNEL_BRANCH` | Rama del kernel source | `stone-v-oss` |
| `CLANG_DIR` | Path a Clang 17 | `sources/toolchain/clang17` |
| `JOBS` | Paralelismo de make | `$(nproc)` |
| `SKIP_CLONE` | Si está seteado, no re-clonar repos existentes | `` |
| `KERNEL_VERSION` | Versión para nombre del ZIP | `5.4.302` |

## Reglas No Negociables

1. Patches en orden estricto: nethunter → qcacld → mtk. Invertir rompe el árbol.
2. Nunca modificar sources/kernel directamente — todos los cambios son patches en patches/.
3. stone_nethunter.config son ADICIONES al defconfig — mergear con merge_config.sh.
4. anykernel.sh DEBE tener device.name1=stone, device.name2=moonstone, device.name3=sunstone.
5. Verificar que Image.gz-dtb existe en out/kernel/arch/arm64/boot/ antes del packaging.
6. Drivers Realtek: solo forks aircrack-ng/RinCat/kelebek333 — los oficiales no tienen injection.
7. Usar CONFIG_LTO_CLANG_THIN=y, nunca FULL — el SM6375 con 5.4 tiene link errors con LTO full.
