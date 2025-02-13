#!/bin/bash

# Cursor ID Modification Tool
# Author: Aminul Islam (@aminulsec)
# Website: https://aminulislam.in
# GitHub: https://github.com/aminulsec
# Description: This script modifies Cursor's device ID, prevents auto-updates, and resets trial limits.

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Get the current user
get_current_user() { [ "$EUID" -eq 0 ] && echo "$SUDO_USER" || echo "$USER"; }

CURRENT_USER=$(get_current_user)
if [ -z "$CURRENT_USER" ]; then
    log_error "Failed to retrieve the username."
    exit 1
fi

# Define config file paths
STORAGE_FILE="/home/$CURRENT_USER/.config/Cursor/User/globalStorage/storage.json"
BACKUP_DIR="/home/$CURRENT_USER/.config/Cursor/User/globalStorage/backups"

# Ensure script is run with sudo
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with sudo."
        echo "Example: sudo $0"
        exit 1
    fi
}

# Kill Cursor processes
check_and_kill_cursor() {
    log_info "Checking for running Cursor processes..."
    local attempt=1 max_attempts=5

    while [ $attempt -le $max_attempts ]; do
        CURSOR_PIDS=$(pgrep -f "[C]ursor" || true)
        if [ -z "$CURSOR_PIDS" ]; then log_info "No running Cursor process found."; return 0; fi
        log_warn "Found running Cursor processes, attempting to terminate..."
        
        for pid in $CURSOR_PIDS; do
            [ $attempt -eq $max_attempts ] && kill -9 "$pid" || kill "$pid"
        done

        sleep 2
        ! pgrep -f "[C]ursor" > /dev/null && log_info "Cursor processes terminated." && return 0
        log_warn "Retrying... attempt $attempt/$max_attempts"
        ((attempt++))
    done

    log_error "Failed to close Cursor after multiple attempts. Close it manually and retry."
    exit 1
}

# Backup configuration
backup_config() {
    [ ! -f "$STORAGE_FILE" ] && log_warn "Configuration file not found, skipping backup." && return 0
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/storage.json.backup_$(date +%Y%m%d_%H%M%S)"
    cp "$STORAGE_FILE" "$backup_file" && chmod 644 "$backup_file" && chown "$CURRENT_USER:$CURRENT_USER" "$backup_file"
    log_info "Configuration backed up to: $backup_file"
}

# Generate random ID
generate_random_id() { head -c 32 /dev/urandom | xxd -p; }

# Generate random UUID
generate_uuid() { uuidgen | tr '[:upper:]' '[:lower:]'; }

# Modify configuration
generate_new_config() {
    command -v xxd &> /dev/null || { log_error "xxd is required. Install with: sudo apt-get install xxd"; exit 1; }
    command -v uuidgen &> /dev/null || { log_error "uuidgen is required. Install with: sudo apt-get install uuid-runtime"; exit 1; }
    [ ! -f "$STORAGE_FILE" ] && log_error "Cursor configuration file not found!" && exit 1

    log_info "Generating new machine ID..."
    echo "$(uuidgen | tr -d '-')" | sudo tee /etc/machine-id > /dev/null

    local machine_id="auth0|user_$(generate_random_id | cut -c 1-32)"
    local mac_machine_id=$(generate_random_id)
    local device_id=$(generate_uuid)
    local sqm_id="{$(generate_uuid)}"

    sed -i "s|\"telemetry\.machineId\": *\"[^\"]*\"|\"telemetry.machineId\": \"$machine_id\"|" "$STORAGE_FILE"
    sed -i "s|\"telemetry\.macMachineId\": *\"[^\"]*\"|\"telemetry.macMachineId\": \"$mac_machine_id\"|" "$STORAGE_FILE"
    sed -i "s|\"telemetry\.devDeviceId\": *\"[^\"]*\"|\"telemetry.devDeviceId\": \"$device_id\"|" "$STORAGE_FILE"
    sed -i "s|\"telemetry\.sqmId\": *\"[^\"]*\"|\"telemetry.sqmId\": \"$sqm_id\"|" "$STORAGE_FILE"

    chmod 444 "$STORAGE_FILE" && chown "$CURRENT_USER:$CURRENT_USER" "$STORAGE_FILE"
    log_info "New configuration applied successfully."
}

# Disable auto-update
disable_auto_update() {
    echo
    log_warn "Do you want to disable Cursor auto-updates?"
    echo "0) No - Keep default settings (Press Enter)"
    echo "1) Yes - Disable auto-updates"
    read -r choice
    
    if [ "$choice" = "1" ]; then
        local updater_path="$HOME/.config/cursor-updater"
        log_info "Disabling auto-updates..."
        
        rm -rf "$updater_path" 2>/dev/null || log_error "Failed to remove cursor-updater directory."
        touch "$updater_path" && chmod 444 "$updater_path" && chown "$CURRENT_USER:$CURRENT_USER" "$updater_path"
        
        command -v chattr &> /dev/null && chattr +i "$updater_path" 2>/dev/null || log_warn "chattr protection failed."

        [ -w "$updater_path" ] && log_error "Failed to set read-only permissions." || log_info "Auto-updates disabled successfully."
    else
        log_info "Keeping default update settings."
    fi
}

# Main function
main() {
    clear
    echo -e "
    ██████╗██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗ 
   ██╔════╝██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗
   ██║     ██║   ██║██████╔╝███████╗██║   ██║██████╔╝
   ██║     ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗
   ╚██████╗╚██████╔╝██║  ██║███████║╚██████╔╝██║  ██║
    ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝
    "
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}   Cursor ID Modification Tool   ${NC}"
    echo -e "${YELLOW}  Created by: Aminul Islam (@aminulsec) ${NC}"
    echo -e "${YELLOW}  Website: https://aminulislam.in  ${NC}"
    echo -e "${YELLOW}  GitHub: https://github.com/aminulsec  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    
    check_permissions
    check_and_kill_cursor
    backup_config
    generate_new_config
    
    log_info "Operation completed! Restart Cursor to apply the changes."
    disable_auto_update
}

# Run the script
main
