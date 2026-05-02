#!/usr/bin/env bash
# Shared utilities: logging, error handling, banners

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_error() {
    local exit_code=$?
    local msg="${1:-Command failed}"
    if [[ $exit_code -ne 0 ]]; then
        err "$msg (exit $exit_code)"
        exit $exit_code
    fi
}

die() {
    err "$*"
    exit 1
}

banner() {
    local msg="$*"
    local len=${#msg}
    local border
    border=$(printf '═%.0s' $(seq 1 $((len + 4))))
    echo -e "\n${BOLD}${CYAN}╔${border}╗${NC}"
    echo -e "${BOLD}${CYAN}║  ${msg}  ║${NC}"
    echo -e "${BOLD}${CYAN}╚${border}╝${NC}\n"
}

require_cmd() {
    command -v "$1" &>/dev/null || die "Required command not found: $1"
}

step_done_file() {
    echo "${REPO_ROOT}/.done_${1}"
}

is_step_done() {
    [[ -f "$(step_done_file "$1")" ]]
}

mark_step_done() {
    touch "$(step_done_file "$1")"
}

# Invalidate steps that depend on KSU mode whenever ${KSU} differs from the
# value cached in ${KSU_STATE_FILE}. Call from build.sh before running steps.
#
# Importante: además de los markers, limpiamos out/kernel/ y los .ko
# out-of-tree de los drivers Realtek. Cambiar KSU mode altera el ABI del
# kernel (CONFIG_KSU añade/quita símbolos), así que las CRCs de Module.symvers
# cambian y todos los módulos deben recompilarse contra el kernel nuevo —
# de lo contrario fallan al cargar con "disagrees about version of symbol
# module_layout".
ksu_mode_sync() {
    local prev=""
    [[ -f "${KSU_STATE_FILE}" ]] && prev="$(cat "${KSU_STATE_FILE}")"
    if [[ "${prev}" != "${KSU}" ]]; then
        if [[ -n "${prev}" ]]; then
            log "KSU mode changed: ${prev} → ${KSU} — invalidating steps 04, 06, 07, 08 + cleaning kernel build"
            # Forzar rebuild completo del kernel: las CRCs cambian con KSU.
            rm -rf "${OUT_DIR}" "${MODULES_DIR}"
            # Borrar .ko out-of-tree de drivers (deben recompilarse contra
            # el kernel nuevo con CRCs nuevas).
            find "${DRIVERS_DIR}" -maxdepth 2 -name "*.ko" -delete 2>/dev/null || true
        else
            log "KSU mode initialized: ${KSU}"
        fi
        rm -f "$(step_done_file 04)" "$(step_done_file 06)" \
              "$(step_done_file 07)" "$(step_done_file 08)"
        echo "${KSU}" > "${KSU_STATE_FILE}"
    fi
}
