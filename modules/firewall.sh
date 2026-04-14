#!/usr/bin/env bash

setup_firewall() {
    log "INFO" "Configuring UFW..."

    ensure_package ufw

    local ufw_status
    ufw_status=$(ufw status 2>/dev/null)

    run ufw default deny incoming
    run ufw default allow outgoing
    register_rollback "_rollback_ufw_policies"

    if echo "$ufw_status" | grep -qE "^${SSH_PORT}/tcp|^${SSH_PORT} "; then
        log "INFO" "UFW rule for port ${SSH_PORT}/tcp already exists"
    else
        run ufw allow "${SSH_PORT}/tcp"
    fi

    if echo "$ufw_status" | grep -q "^Status: active"; then
        log "INFO" "UFW already active"
    else
        run ufw --force enable
        register_rollback "_rollback_ufw_disable"
    fi

    log "INFO" "Firewall configured"
}

_rollback_ufw_policies() {
    run ufw default allow incoming
    run ufw default deny outgoing
}

_rollback_ufw_disable() {
    run ufw --force disable
}
