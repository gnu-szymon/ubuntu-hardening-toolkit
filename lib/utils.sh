#!/usr/bin/env bash
set -Eeuo pipefail

readonly LOG_DIR="logs"
readonly LOG_FILE="$LOG_DIR/toolkit.log"

mkdir -p "$LOG_DIR"

declare -a ROLLBACK_ACTIONS=()

APT_UPDATED=0

log() {
	local level="$1"
	local message="$2"
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"	
}

die() {
	log "ERROR" "$1"
	exit 1
}

require_root(){
	(( EUID == 0 )) || die "Run as root"
}

run() {
	if [[ "${DRY_RUN}" == "yes" ]]; then
		log "DRY-RUN" "$*"
		return 0
	fi

	log "INFO" "Running: $*"
	"$@"
}

apt_update_once() {
	(( APT_UPDATED )) && return

	run apt update
	APT_UPDATED=1
}

get_user_home() {
	local user="${SUDO_USER:-$USER}"
	local home

	home=$(getent passwd "$user" | cut -d: -f6)
	[[ -n "$home" ]] || die "Could not determine home for user $user"

	echo "$home"
}

check_ssh_keys_exist() {
	local home
	home=$(get_user_home)

	[[ -f "${home}/.ssh/authorized_keys" ]] || \
		die "No SSH authorized_keys found for user ${SUDO_USER:-$USER}"
}

confirm_dangerous_action() {
	[[ "${DRY_RUN}" == "yes" ]] && return

	local message="$1"

	echo
	read -r -p "$message (type YES to continue): " confirm
	[[ "$confirm" == "YES" ]] || die "Aborted by user"
}

validate_port() {
	local port="$1"

	[[ "$port" =~ ^[0-9]+$ ]] || die "Invalid SSH port: $port"
	(( port >= 1 && port <= 65535 )) || die "Invalid SSH port: $port"
}

ensure_package() {
	local pkg="$1"

	dpkg -s "$pkg" &>/dev/null && return

	apt_update_once
	run apt install -y "$pkg"

	register_rollback "apt remove -y '$pkg'"
}

register_rollback() {
	ROLLBACK_ACTIONS+=("$*")
}

run_rollbacks() {
	log "WARN" "Running rollback actions..."

	for (( i=${#ROLLBACK_ACTIONS[@]}-1; i>=0; i-- )); do
		eval "${ROLLBACK_ACTIONS[i]}"
	done
}

handle_error() {
	log "ERROR" "Failure detected, starting rollback..."

	if [[ "${DRY_RUN}" == "yes" ]]; then
		log "INFO" "DRY-RUN enabled, skipping rollback"
		exit 1
	fi

	run_rollbacks
	log "ERROR" "Rollback completed"
	exit 1
}
