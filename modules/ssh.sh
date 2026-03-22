#!/usr/bin/env bash
set -Eeuo pipefail

SSH_DIR="/etc/ssh/sshd_config.d"
HARDEN_FILE="${SSH_DIR}/99-hardening.conf"

ensure_sshd_dir() {
	run mkdir -p "$SSH_DIR"
}

write_sshd_config() {
	local password_auth="$1"
	local tmp_file

	tmp_file=$(mktemp)

	cat > "$tmp_file" <<EOF
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication ${password_auth}
EOF

	if [[ -f "$HARDEN_FILE" ]] && cmp -s "$tmp_file" "$HARDEN_FILE"; then
		log "INFO" "SSH config already up to date"
		rm -f "$tmp_file"
		return
	fi

	run mv "$tmp_file" "$HARDEN_FILE"
}

validate_sshd() {
	command -v sshd >/dev/null || die "sshd not found"
	sshd -t || die "Invalid SSH configuration"
}

restart_ssh_safe() {
	run systemctl restart ssh

	systemctl is-active --quiet ssh || \
		die "SSH failed to restart"
}

configure_ssh() {
	log "INFO" "Configuring SSH..."

	validate_port "$SSH_PORT"
	ensure_sshd_dir

	write_sshd_config "yes"
	validate_sshd
	restart_ssh_safe

	if [[ "$DISABLE_PASSWORD_AUTH" != "yes" ]]; then
		log "INFO" "Password authentication left enabled (default)"
		return
	fi

	check_ssh_keys_exist
	confirm_dangerous_action "Disabling password authentication"

	write_sshd_config "no"
	validate_sshd
	restart_ssh_safe

	log "INFO" "Password authentication disabled safely"
}
