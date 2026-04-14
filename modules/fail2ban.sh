#!/usr/bin/env bash

readonly JAIL_DIR="/etc/fail2ban/jail.d"
readonly JAIL_FILE="${JAIL_DIR}/ssh-hardening.conf"

_write_jail_config() {
    local tmp_file
    tmp_file=$(mktemp)

    cat > "$tmp_file" <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
backend = systemd
maxretry = ${FAIL2BAN_MAXRETRY}
findtime = ${FAIL2BAN_FINDTIME}
bantime = ${FAIL2BAN_BANTIME}
ignoreip = 127.0.0.1/8 ::1
EOF

    if [[ -f "$JAIL_FILE" ]] && cmp -s "$tmp_file" "$JAIL_FILE"; then
        log "INFO" "Fail2Ban config already up to date"
        rm -f "$tmp_file"
        return
    fi

    if [[ ! -d "$JAIL_DIR" ]]; then
        run mkdir -p "$JAIL_DIR"
        register_rollback "_rollback_fail2ban_dir"
    fi

    if [[ -f "$JAIL_FILE" ]]; then
        run cp "$JAIL_FILE" "${JAIL_FILE}.bak"
        register_rollback "_rollback_fail2ban_config_restore"
    else
        register_rollback "_rollback_fail2ban_config_remove"
    fi

    run mv "$tmp_file" "$JAIL_FILE"
    run chmod 600 "$JAIL_FILE"
}

_validate_fail2ban() {
    [[ "${DRY_RUN:-no}" == "yes" ]] && return
    command -v fail2ban-client >/dev/null || die "fail2ban not installed"
    fail2ban-client -t &>/dev/null || die "Fail2Ban configuration test failed"
}

_enable_fail2ban() {
    run systemctl enable --now fail2ban

    register_rollback "_rollback_fail2ban_service"

    if [[ "${DRY_RUN:-no}" != "yes" ]]; then
        systemctl is-active --quiet fail2ban || die "Fail2Ban failed to start"
    fi
}

setup_fail2ban() {
    log "INFO" "Configuring Fail2Ban..."

    ensure_package fail2ban

    _write_jail_config
    _validate_fail2ban
    _enable_fail2ban

    log "INFO" "Fail2Ban configured"
}

_rollback_fail2ban_dir() {
    run rm -rf "$JAIL_DIR"
}

_rollback_fail2ban_config_restore() {
    run mv "${JAIL_FILE}.bak" "$JAIL_FILE"
}

_rollback_fail2ban_config_remove() {
    run rm -f "$JAIL_FILE"
}

_rollback_fail2ban_service() {
    run systemctl stop fail2ban
    run systemctl disable fail2ban
}
