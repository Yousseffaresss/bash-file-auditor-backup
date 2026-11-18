#!/usr/bin/env bash

# Write one timestamped message to the project log.
log_action() {
    local message="$1"
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s - %s\n' "$timestamp" "$message" >> "$LOG_FILE"
}

# Make sure the directory supplied by the user exists.
require_dir() {
    local directory_path="$1"

    if [[ -d "$directory_path" ]]; then
        return 0
    else
        printf 'Error: directory does not exist: %s\n' "$directory_path" >&2
        return 1
    fi
}
