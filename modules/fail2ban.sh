#!/usr/bin/env bash
set -Eeuo pipefail

JAIL_DIR="/etc/fail2ban/jail.d"
JAIL_FILE="${JAIL_DIR}/ssh-hardening.conf"

setup_fail2ban() {
        log "INFO" "Configuring Fail2Ban..."

        ensure_package fail2ban

        write_jail_config
        validate_fail2ban
        enable_fail2ban

        log "INFO" "Fail2Ban configured"
}

write_jail_config() {
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

        run mkdir -p "$JAIL_DIR"

        if [[ -f "$JAIL_FILE" ]]; then
                run cp "$JAIL_FILE" "${JAIL_FILE}.bak"
                register_rollback "mv '${JAIL_FILE}.bak' '$JAIL_FILE'"
        else
                register_rollback "rm -f '$JAIL_FILE'"
        fi

        run mv "$tmp_file" "$JAIL_FILE"
}

validate_fail2ban() {
        [[ "${DRY_RUN}" == "yes" ]] && return

        command -v fail2ban-client >/dev/null || die "fail2ban not installed"

        fail2ban-client -t &>/dev/null || die "Fail2Ban configuration test failed"
}

enable_fail2ban() {
        run systemctl enable --now fail2ban

        register_rollback "systemctl stop fail2ban"
        register_rollback "systemctl disable fail2ban"

        if [[ "${DRY_RUN}" != "yes" ]]; then
                systemctl is-active --quiet fail2ban || \
                        die "Fail2Ban failed to start"
        fi
}
