set -Eeuo pipefail

cd "$(dirname "$0")"

umask 077

source lib/utils.sh

require_root
check_system

for _file in config/default.conf modules/firewall.sh \
             modules/ssh.sh modules/fail2ban.sh modules/updates.sh; do
    [[ -f "$_file" ]] || die "Missing file: $_file"
done

source config/default.conf
source modules/firewall.sh
source modules/ssh.sh
source modules/fail2ban.sh
source modules/updates.sh

trap handle_error ERR

validate_config
validate_port "$SSH_PORT"

log "INFO" "Starting Ubuntu Hardening Toolkit"

if [[ "$ENABLE_UFW"      == "yes" ]]; then setup_firewall;  fi
if [[ "$CONFIGURE_SSH"   == "yes" ]]; then configure_ssh;   fi
if [[ "$ENABLE_FAIL2BAN" == "yes" ]]; then setup_fail2ban;  fi
if [[ "$AUTO_UPDATES"    == "yes" ]]; then setup_updates;   fi

log "INFO" "Hardening complete"
