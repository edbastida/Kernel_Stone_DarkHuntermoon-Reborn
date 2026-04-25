#!/usr/bin/env bash
# Global variables and paths — single source of truth for all scripts

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

KERNEL_BRANCH="${KERNEL_BRANCH:-16}"
KERNEL_VERSION="${KERNEL_VERSION:-5.4.302}"
JOBS="${JOBS:-$(nproc)}"
SKIP_CLONE="${SKIP_CLONE:-}"

CLANG_DIR="${REPO_ROOT}/sources/toolchain/clang17"
KERNEL_DIR="${REPO_ROOT}/sources/kernel"
DRIVERS_DIR="${REPO_ROOT}/sources/drivers"
AK3_DIR="${REPO_ROOT}/sources/anykernel3"

OUT_DIR="${REPO_ROOT}/out/kernel"
MODULES_DIR="${REPO_ROOT}/out/modules"
ZIP_DIR="${REPO_ROOT}/out/zip"

PATCHES_DIR="${REPO_ROOT}/patches"
CONFIG_DIR="${REPO_ROOT}/config"
ANYKERNEL_DIR="${REPO_ROOT}/anykernel"

KERNEL_DEFCONFIG="stone_defconfig"
NETHUNTER_CONFIG="${CONFIG_DIR}/stone_nethunter.config"

KERNEL_REPO="https://github.com/kamikaonashi/kernel_xiaomi_stone"
AK3_REPO="https://github.com/osm0sis/AnyKernel3"
CLANG_REPO="https://github.com/ZyCromerZ/Clang"
CLANG_BRANCH="17"
KSU_SETUP_URL="https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh"

declare -A DRIVER_REPOS=(
    [rtl8188eus]="https://github.com/aircrack-ng/rtl8188eus"
    [rtl88x2bu]="https://github.com/RinCat/RTL88x2BU-Linux-Driver"
    [rtl8192eu]="https://github.com/clnhub/rtl8192eu-linux"
    [rtl8812au]="https://github.com/aircrack-ng/rtl8812au"
    [rtl8188fu]="https://github.com/kelebek333/rtl8188fu"
)
declare -A DRIVER_BRANCHES=(
    [rtl8812au]="v5.6.4.2"
)
