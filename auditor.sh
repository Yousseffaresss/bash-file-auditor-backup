#!/usr/bin/env bash

# Find the project folder so the script works from any location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TARGET_DIR="${1:-$SCRIPT_DIR/sample_data}"
LOG_FILE="$SCRIPT_DIR/auditor.log"

# List every file and folder, then print their totals.
scan_directory() {
    local file_count=0
    local folder_count=0
    local item
    local relative_path

    if ! require_dir "$TARGET_DIR"; then
        log_action "Scan failed: $TARGET_DIR"
        return 1
    fi

    while IFS= read -r -d '' item; do
        relative_path="${item#"$TARGET_DIR"/}"

        if [[ -f "$item" ]]; then
            printf '[file] %s\n' "$relative_path"
            file_count=$((file_count + 1))
        elif [[ -d "$item" ]]; then
            printf '[dir ] %s\n' "$relative_path"
            folder_count=$((folder_count + 1))
        fi
    done < <(find "$TARGET_DIR" -mindepth 1 -print0)

    printf '\nFiles: %s\nFolders: %s\n' "$file_count" "$folder_count"
    log_action "Directory scanned: $TARGET_DIR"
}


# Count files that cannot be read and files that can be executed.
permission_audit() {
    local unreadable_count=0
    local executable_count=0
    local file
    local relative_path
    local permissions

    if ! require_dir "$TARGET_DIR"; then
        log_action "Permission audit failed: $TARGET_DIR"
        return 1
    fi

    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            relative_path="${file#"$TARGET_DIR"/}"
            permissions="$(stat -c '%A' -- "$file")"
            printf '%s  %s\n' "$permissions" "$relative_path"

            if [[ ! -r "$file" ]]; then
                unreadable_count=$((unreadable_count + 1))
            fi

            if [[ -x "$file" ]]; then
                executable_count=$((executable_count + 1))
            fi
        fi
    done < <(find "$TARGET_DIR" -type f -print0)

    printf '\nUnreadable files: %s\n' "$unreadable_count"
    printf 'Executable files: %s\n' "$executable_count"
    log_action "Permission audit completed: $TARGET_DIR"
}


# Count files by extension using an associative array.
extension_report() {
    local -A extension_counts=()
    local -a files=()
    local file
    local file_name
    local extension
    local count

    if ! require_dir "$TARGET_DIR"; then
        log_action "Extension report failed: $TARGET_DIR"
        return 1
    fi

    extension_counts[other]=0
    mapfile -d '' -t files < <(find "$TARGET_DIR" -type f -print0)

    for file in "${files[@]}"; do
        file_name="${file##*/}"

        if [[ "$file_name" == *.* ]]; then
            extension="${file_name##*.}"
        else
            extension="other"
        fi

        if [[ -z "$extension" ]]; then
            extension="other"
        fi

        count="${extension_counts[$extension]:-0}"
        extension_counts["$extension"]=$((count + 1))
    done

    printf 'Extension report:\n'
    for extension in "${!extension_counts[@]}"; do
        printf '%-8s: %s\n' "$extension" "${extension_counts[$extension]}"
    done

    log_action "Extension report completed: $TARGET_DIR"
}


# Find files whose relative paths contain the text entered by the user.
search_file() {
    local search_text
    local file
    local relative_path
    local found=0

    if ! require_dir "$TARGET_DIR"; then
        log_action "Search failed: $TARGET_DIR"
        return 1
    fi

    read -r -p "Enter search text: " search_text

    while IFS= read -r -d '' file; do
        relative_path="${file#"$TARGET_DIR"/}"

        if [[ "$relative_path" == *"$search_text"* ]]; then
            printf '%s\n' "$relative_path"
            found=1
        fi
    done < <(find "$TARGET_DIR" -type f -print0)

    if [[ "$found" -eq 0 ]]; then
        printf 'No matching files found.\n'
    fi

    log_action "Search completed: $search_text"
}


BACKUP_DIR="$SCRIPT_DIR/backups"

# Copy readable files to the backup folder with a timestamp in each name.
backup_all() {
    local saved_count=0
    local skipped_count=0
    local timestamp
    local file
    local relative_path
    local backup_name
    local destination

    if ! require_dir "$TARGET_DIR"; then
        log_action "Backup failed: $TARGET_DIR"
        return 1
    fi

    if ! mkdir -p "$BACKUP_DIR"; then
        printf 'Error: could not create backup folder.\n' >&2
        log_action "Backup failed: could not create backup folder"
        return 1
    fi

    while IFS= read -r -d '' file; do
        relative_path="${file#"$TARGET_DIR"/}"
        backup_name="${relative_path//\//__}"
        timestamp="$(date '+%Y%m%d_%H%M%S_%N')"
        destination="$BACKUP_DIR/${backup_name}_${timestamp}.bak"

        if [[ -r "$file" ]]; then
            if cp -- "$file" "$destination"; then
                saved_count=$((saved_count + 1))
            else
                printf 'Error: could not back up %s\n' "$relative_path" >&2
                skipped_count=$((skipped_count + 1))
            fi
        else
            printf 'Skipping unreadable file: %s\n' "$relative_path"
            skipped_count=$((skipped_count + 1))
        fi
    done < <(find "$TARGET_DIR" -type f -print0)

    printf 'Files saved: %s\n' "$saved_count"
    printf 'Files skipped: %s\n' "$skipped_count"
    log_action "Backup completed: saved $saved_count, skipped $skipped_count"
}


# Show the names of saved backup files.
list_backups() {
    local backup_file
    local backup_count=0

    printf 'Saved backups:\n\n'

    if [[ -d "$BACKUP_DIR" ]]; then
        while IFS= read -r -d '' backup_file; do
            printf '%s\n' "${backup_file##*/}"
            backup_count=$((backup_count + 1))
        done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.bak' -print0)
    fi

    if [[ "$backup_count" -eq 0 ]]; then
        printf 'No backups yet\n'
    fi

    log_action "Backup list viewed: $backup_count files"
}


# Restore one named backup without replacing an existing file.
restore_backup() {
    local backup_name="$1"
    local backup_path
    local original_name
    local destination

    if ! require_dir "$TARGET_DIR"; then
        log_action "Restore failed: $TARGET_DIR"
        return 1
    fi

    if [[ -z "$backup_name" ]]; then
        read -r -p "Enter backup filename to restore: " backup_name
    fi

    if [[ "$backup_name" == */* || -z "$backup_name" ]]; then
        printf 'Error: enter a backup filename only.\n' >&2
        log_action "Restore failed: invalid backup name"
        return 1
    fi

    backup_path="$BACKUP_DIR/$backup_name"

    if [[ ! -f "$backup_path" ]]; then
        printf 'Error: backup not found: %s\n' "$backup_name" >&2
        log_action "Restore failed: backup not found: $backup_name"
        return 1
    fi

    if [[ "$backup_name" =~ ^(.+)_([0-9]{8})_([0-9]{6})_([0-9]{9})\.bak$ ]]; then
        original_name="${BASH_REMATCH[1]}"
    else
        original_name="${backup_name%.bak}"
    fi

    destination="$TARGET_DIR/restored_${original_name}"

    if [[ -e "$destination" ]]; then
        printf 'Error: destination already exists: %s\n' "$destination" >&2
        log_action "Restore failed: destination exists: $destination"
        return 1
    fi

    if cp -- "$backup_path" "$destination"; then
        printf 'Restored as: %s\n' "${destination##*/}"
        log_action "File restored: $backup_name"
    else
        printf 'Error: could not restore %s\n' "$backup_name" >&2
        log_action "Restore failed while copying: $backup_name"
        return 1
    fi
}


# Display the interactive menu.
show_menu() {
    printf '\n========== FILE AUDITOR ==========\n'
    printf '1. Scan Directory\n'
    printf '2. Permission Audit\n'
    printf '3. Extension Report\n'
    printf '4. Search File\n'
    printf '5. Backup All\n'
    printf '6. List Backups\n'
    printf '7. Restore Backup\n'
    printf '8. Exit\n'
}

# Keep showing the menu until the user chooses Exit.
menu_loop() {
    local choice

    while true; do
        show_menu
        read -r -p "Choose an option: " choice || return 0

        if [[ "$choice" == "1" ]]; then
            scan_directory
        elif [[ "$choice" == "2" ]]; then
            permission_audit
        elif [[ "$choice" == "3" ]]; then
            extension_report
        elif [[ "$choice" == "4" ]]; then
            search_file
        elif [[ "$choice" == "5" ]]; then
            backup_all
        elif [[ "$choice" == "6" ]]; then
            list_backups
        elif [[ "$choice" == "7" ]]; then
            list_backups
            if ! restore_backup; then
                return 1
            fi
        elif [[ "$choice" == "8" ]]; then
            log_action "Program exited"
            printf 'Goodbye!\n'
            return 0
        else
            printf 'Error: invalid choice. Please try again.\n'
        fi
    done
}

# Print the supported command-line formats.
usage() {
    printf 'Usage:\n'
    printf '  %s [TARGET_DIR]\n' "${0##*/}"
    printf '  %s TARGET_DIR {scan|perms|ext|backup}\n' "${0##*/}"
}

# Run a requested command directly, or open the interactive menu.
main() {
    local action

    if [[ "$#" -gt 2 ]]; then
        usage
        return 2
    fi

    if [[ "$#" -eq 2 ]]; then
        action="$2"

        case "$action" in
            scan)
                scan_directory
                ;;
            perms)
                permission_audit
                ;;
            ext)
                extension_report
                ;;
            backup)
                backup_all
                ;;
            *)
                usage
                return 2
                ;;
        esac
    else
        menu_loop
    fi
}

main "$@"
