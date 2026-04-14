#!/usr/bin/env bash

readonly LOG_DIR="logs"
readonly LOG_FILE="$LOG_DIR/toolkit.log"

mkdir -p "$LOG_DIR"

declare -a ROLLBACK_ACTIONS=()
declare -i APT_UPDATED=0

# Logs

log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

die() {
    log "ERROR" "$1"
    exit 1
}

# Reqs

require_root() {
    (( EUID == 0 )) || die "Run as root"
}

check_system() {
    [[ -f /etc/os-release ]] || die "Cannot detect OS: /etc/os-release not found"

    local os_id
    os_id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    [[ "$os_id" == "ubuntu" ]] || die "This toolkit requires Ubuntu (detected: ${os_id:-unknown})"

    command -v systemctl &>/dev/null || die "systemd is required but not found"
}

# Run

run() {
    if [[ "${DRY_RUN:-no}" == "yes" ]]; then
        log "DRY-RUN" "$*"
        return 0
    fi

    log "INFO" "Running: $*"
    "$@"
}

# Rollback

register_rollback() {
    ROLLBACK_ACTIONS+=("$1")
}

run_rollbacks() {
    log "WARN" "Running rollback actions..."

    local i
    for (( i=${#ROLLBACK_ACTIONS[@]}-1; i>=0; i-- )); do
        "${ROLLBACK_ACTIONS[i]}" || log "WARN" "Rollback step failed: ${ROLLBACK_ACTIONS[i]}"
    done
}

handle_error() {
    log "ERROR" "Failure detected, starting rollback..."

    if [[ "${DRY_RUN:-no}" == "yes" ]]; then
        log "INFO" "DRY-RUN enabled, skipping rollback"
        exit 1
    fi

    run_rollbacks
    log "ERROR" "Rollback completed"
    exit 1
}

# APT

apt_update_once() {
    (( APT_UPDATED )) && return
    run apt-get update
    APT_UPDATED=1
}

ensure_package() {
    local pkg="$1"

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "^install ok installed$"; then
        return
    fi

    apt_update_once
    run apt-get install -y --no-install-recommends "$pkg"

    register_rollback "_rollback_remove_pkg_${pkg//[^a-zA-Z0-9_]/_}"

    local fn="_rollback_remove_pkg_${pkg//[^a-zA-Z0-9_]/_}"
    local safe_pkg="$pkg"
    eval "${fn}() { run apt-get remove -y $(printf '%q' "$safe_pkg"); }"
}

# Validation

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] || die "Invalid SSH port: $port"
    (( port >= 1 && port <= 65535 )) || die "Invalid SSH port: $port"
}

validate_config() {
    local bool_vars=(
        DISABLE_ROOT_LOGIN DISABLE_PASSWORD_AUTH
        ENABLE_UFW AUTO_UPDATES CONFIGURE_SSH
        DRY_RUN ENABLE_FAIL2BAN
    )

    local var val
    for var in "${bool_vars[@]}"; do
        val="${!var}"
        [[ "$val" == "yes" || "$val" == "no" ]] || \
            die "Config error: $var must be 'yes' or 'no' (got: '${val}')"
    done

    [[ "$FAIL2BAN_MAXRETRY" =~ ^[0-9]+$ ]] || \
        die "Config error: FAIL2BAN_MAXRETRY must be a positive integer (got: '${FAIL2BAN_MAXRETRY}')"

    [[ "$FAIL2BAN_FINDTIME" =~ ^[0-9]+[smhd]$ ]] || \
        die "Config error: FAIL2BAN_FINDTIME must be in format like 10m, 1h, 1d (got: '${FAIL2BAN_FINDTIME}')"

    [[ "$FAIL2BAN_BANTIME" =~ ^[0-9]+[smhd]$ ]] || \
        die "Config error: FAIL2BAN_BANTIME must be in format like 10m, 1h, 1d (got: '${FAIL2BAN_BANTIME}')"
}

# SSH

get_user_home() {
    local user="${SUDO_USER:-}"

    if [[ -z "$user" ]]; then
        log "WARN" "SUDO_USER not set — looking for SSH keys in /root/.ssh/"
        user="root"
    fi

    local home
    home=$(getent passwd "$user" | cut -d: -f6)
    [[ -n "$home" ]] || die "Could not determine home for user $user"

    echo "$home"
}

check_ssh_keys_exist() {
    local home
    home=$(get_user_home)

    [[ -f "${home}/.ssh/authorized_keys" ]] || \
        die "No SSH authorized_keys found — aborting password auth disable"
}

confirm_dangerous_action() {
    [[ "${DRY_RUN:-no}" == "yes" ]] && return

    [[ -t 0 ]] || die "Cannot confirm dangerous action in non-interactive mode"

    local message="$1"
    echo
    read -r -p "$message (type YES to continue): " confirm
    [[ "$confirm" == "YES" ]] || die "Aborted by user"
}
