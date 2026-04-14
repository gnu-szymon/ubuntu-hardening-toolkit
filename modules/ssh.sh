#!/usr/bin/env bash

readonly SSH_DIR="/etc/ssh/sshd_config.d"
readonly HARDEN_FILE="${SSH_DIR}/99-hardening.conf"

_ensure_sshd_dir() {
    if [[ ! -d "$SSH_DIR" ]]; then
        run mkdir -p "$SSH_DIR"
        register_rollback "_rollback_sshd_dir"
    fi
}

_write_sshd_config() {
    local password_auth="$1"
    local permit_root

    [[ "$DISABLE_ROOT_LOGIN" == "yes" ]] && permit_root="no" || permit_root="yes"

    local tmp_file
    tmp_file=$(mktemp)

    cat > "$tmp_file" <<EOF
Port ${SSH_PORT}
PermitRootLogin ${permit_root}
PasswordAuthentication ${password_auth}
EOF

    if [[ -f "$HARDEN_FILE" ]] && cmp -s "$tmp_file" "$HARDEN_FILE"; then
        log "INFO" "SSH config already up to date"
        rm -f "$tmp_file"
        return
    fi

    if [[ -f "$HARDEN_FILE" ]]; then
        run cp "$HARDEN_FILE" "${HARDEN_FILE}.bak"
        register_rollback "_rollback_sshd_config_restore"
    else
        register_rollback "_rollback_sshd_config_remove"
    fi

    run mv "$tmp_file" "$HARDEN_FILE"
    run chmod 600 "$HARDEN_FILE"
}

_validate_sshd() {
    command -v sshd >/dev/null || die "sshd not found"
    sshd -t || die "Invalid SSH configuration"
}

_restart_ssh_safe() {
    register_rollback "_rollback_sshd_restart"
    run systemctl restart ssh

    systemctl is-active --quiet ssh || die "SSH failed to restart"
}

configure_ssh() {
    log "INFO" "Configuring SSH..."

    _ensure_sshd_dir

    if [[ "$DISABLE_PASSWORD_AUTH" == "yes" ]]; then
        check_ssh_keys_exist
        confirm_dangerous_action "Disabling password authentication"
        _write_sshd_config "no"
        log "INFO" "Password authentication will be disabled"
    else
        _write_sshd_config "yes"
        log "INFO" "Password authentication left enabled"
    fi

    _validate_sshd
    _restart_ssh_safe

    log "INFO" "SSH configured"
}

_rollback_sshd_dir() {
    run rm -rf "$SSH_DIR"
}

_rollback_sshd_config_restore() {
    run mv "${HARDEN_FILE}.bak" "$HARDEN_FILE"
}

_rollback_sshd_config_remove() {
    run rm -f "$HARDEN_FILE"
}

_rollback_sshd_restart() {
    log "WARN" "Attempting SSH service rollback..."
    run systemctl restart ssh
}
