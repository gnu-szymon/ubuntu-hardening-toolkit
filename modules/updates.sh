#!/usr/bin/env bash
# updates.sh — konfiguracja automatycznych aktualizacji

setup_updates() {
    log "INFO" "Setting up automatic updates..."

    ensure_package unattended-upgrades
    run dpkg-reconfigure -f noninteractive unattended-upgrades

    log "INFO" "Automatic updates configured"
}
