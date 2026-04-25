#!/usr/bin/env bash
# Entry point — orchestrates all build steps end-to-end.
# Usage:
#   bash build.sh                    # full build (steps 01–08)
#   bash build.sh --step=configure   # step 06 only
#   bash build.sh --step=compile     # step 07 only
#   bash build.sh --step=package     # steps 07–08
#   bash build.sh --clean            # remove .done_* markers to force re-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/config.sh"
source "${SCRIPT_DIR}/scripts/lib/utils.sh"

export REPO_ROOT="${SCRIPT_DIR}"

# Tee all output to build-main.log (only when not already redirected)
if [[ -z "${_BUILD_LOGGING:-}" ]]; then
    export _BUILD_LOGGING=1
    mkdir -p "${REPO_ROOT}/out"
    exec > >(tee "${REPO_ROOT}/out/build-main.log") 2>&1
fi

STEP=""
CLEAN=0

for arg in "$@"; do
    case "${arg}" in
        --step=*)  STEP="${arg#--step=}" ;;
        --clean)   CLEAN=1 ;;
        *)         die "Unknown argument: ${arg}" ;;
    esac
done

if [[ ${CLEAN} -eq 1 ]]; then
    log "Removing .done_* markers..."
    rm -f "${REPO_ROOT}"/.done_*
    ok "Done markers removed. Next run will re-execute all steps."
    exit 0
fi

run_step() {
    local num="$1"
    bash "${SCRIPT_DIR}/scripts/${num}.sh"
}

case "${STEP}" in
    "")
        banner "nethunter-stone — Full Build"
        run_step "01_setup_env"
        run_step "02_clone_sources"
        run_step "03_apply_patches"
        run_step "04_integrate_ksu"
        run_step "05_add_drivers"
        run_step "06_configure"
        run_step "07_build"
        run_step "08_package"
        ;;
    configure)
        run_step "06_configure"
        ;;
    compile)
        run_step "07_build"
        ;;
    package)
        run_step "07_build"
        run_step "08_package"
        ;;
    *)
        die "Unknown step: ${STEP}. Valid: configure | compile | package"
        ;;
esac
