#!/usr/bin/env bash
set -Eeuo pipefail

source config/default.conf
source lib/utils.sh
source modules/firewall.sh
source modules/ssh.sh
source modules/fail2ban.sh
source modules/updates.sh

trap handle_error ERR

require_root

log "INFO" "Starting Ubuntu Hardening Toolkit"

validate_port "$SSH_PORT"

[[ "$ENABLE_UFW" == "yes" ]] && setup_firewall
[[ "$CONFIGURE_SSH" == "yes" ]] && configure_ssh || log "INFO" "Skipping SSH configuration"
[[ "$ENABLE_FAIL2BAN" == "yes" ]] && setup_fail2ban
[[ "$AUTO_UPDATES" == "yes" ]] && setup_updates

log "INFO" "Hardening complete"
