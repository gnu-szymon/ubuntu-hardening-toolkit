#!/usr/bin/env bash
set -Eeuo pipefail

setup_firewall() {
	log "INFO" "Configuring UFW..."

	ensure_package ufw

	if ufw status | grep -q "^Status: active"; then
		log "INFO" "UFW already enabled"
		return
	fi

	run ufw default deny incoming
	run ufw default allow outgoing
	run ufw allow "${SSH_PORT}/tcp"
	run ufw --force enable

	register_rollback "ufw --force disable"

	log "INFO" "Firewall configured"
}
