#!/usr/bin/env bash

# =============================================================================
# Moverino - Ultimate File & Directory Transfer Utility
#
# Description : Flexible, modular, and extensible copy tool supporting
#               local and network transfers with progress visualization,
#               batch execution, pattern matching, parallelism, and more.
#
# Author       : flipflopsen
# License      : MIT
# Updated      : 2025-07-14
# =============================================================================

# ---------------------------- Safety Shell Flags -----------------------------
set -o errexit   # Abort on any error
set -o nounset   # Treat unset variables as errors
set -o pipefail  # Catch failures in pipes
shopt -s globstar 2>/dev/null || true  # Enable ** glob if supported

# ------------------------------ Global Config --------------------------------
SCRIPT_NAME="${0##*/}"
VERSION="3.0.0"

# Runtime configuration (defaults)
COPY_METHOD="cp"          # Method: cp | rsync | dd | scp | ncp | sharing | cpy
PV_ENABLED=false          # Use pv for progress
PARALLEL_JOBS=1           # Parallel transfers (1 = serial)
PRESERVE_ATTRS=false      # Preserve ownership & timestamps
OVERWRITE_MODE="ask"      # ask | force | skip
BATCH_FILE=""             # Read operations from file
PATTERN_MODE=false        # Treat source as glob / regex pattern

# Operation queue
declare -a QUEUE_SRC       # Source items (expanded)
declare -a QUEUE_DEST      # Destination path (per item)
declare -a QUEUE_FLAGS     # Flags (is_recursive, etc.)

# =============================================================================
# Utility Helpers
# =============================================================================
msg()  { printf '%s\n' "$*"; }
err()  { printf '❌ %s\n' "$*" >&2; }
warn() { printf '⚠️  %s\n' "$*" >&2; }

print_version() { msg "$SCRIPT_NAME v$VERSION"; }

print_usage() {
    cat << EOF
$SCRIPT_NAME – Ultimate File & Directory Transfer Utility (v$VERSION)

Usage: $SCRIPT_NAME [OPTIONS] --destination DIR [SOURCE ...]
       $SCRIPT_NAME --batch FILE [OPTIONS]

GENERAL OPTIONS
  -h, --help               Show this help and exit
  -v, --version            Show version information and exit
  -d, --destination DIR    Destination directory / remote URI
  -m, --method TYPE        Copy backend (cp|rsync|dd|scp|ncp|sharing|cpy)
  --pv / --no-pv           Enable/disable progress with pv (default: off)
  -p, --pattern            Treat SOURCE arguments as glob patterns
  -P, --parallel N         Run up to N transfers in parallel (default: 1)
  --preserve               Preserve attributes/ownership/timestamps
  -f, --force              Overwrite existing targets without asking
  -n, --no-overwrite       Never overwrite (skip existing targets)
  -b, --batch FILE         Execute operations defined in FILE (one per line)

SOURCE INPUT (interactive if none specified and no batch file)
  Each SOURCE may be a file, directory, or remote URI. Append -R for recursive
  directory copy and -r NEWNAME to rename at destination, e.g:
      /path/data -R
      user@host:/remote/file -r newname

Batch file format mirrors the SOURCE syntax above.
EOF
}

confirm() {
    local prompt="$1" default="${2:-y}" reply
    [[ "$default" == y ]] && prompt+=" [Y/n] " || prompt+=" [y/N] "
    read -r -p "$prompt" reply || true
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[yY](es)?$ ]]
}

normalize_path() {
    local p="$1"
    [[ "$p" == ~* ]] && p="${p/#~/$HOME}"
    [[ "$p" != /* && ! "$p" =~ :/ ]] && p="$PWD/$p"   # not remote, make abs
    printf '%s' "${p%%/}"
}

# Wrap backend command with pv if enabled and applicable
with_pv() {
    local src="$1" dest="$2"; shift 2
    if $PV_ENABLED && command -v pv >/dev/null 2>&1 && [[ -f "$src" ]]; then
        pv -pterb "$src" | "$@" "$dest"
    else
        "$@" "$src" "$dest"
    fi
}

# =============================================================================
# Backend Implementations (each must accept src dest recursive)
# =============================================================================
_copy_cp() {
    local src="$1" dest="$2" rec="$3"; shift 3
    local flags=("-v")
    $PRESERVE_ATTRS && flags+=("-a")
    [[ "$rec" == true ]] && flags+=("-R")
    with_pv "$src" "$dest" cp "${flags[@]}"
}

_copy_rsync() {
    local src="$1" dest="$2" rec="$3"
    local flags=("-av" --progress)
    ! $PRESERVE_ATTRS && flags+=("--no-owner" "--no-group" "--no-perms")
    [[ "$PARALLEL_JOBS" -gt 1 ]] && flags+=("--whole-file")
    [[ "$OVERWRITE_MODE" == force ]] && flags+=("--inplace")
    [[ "$rec" == false ]] && flags+=("-d")
    rsync "${flags[@]}" "$src" "$dest"
}

_copy_dd() {
    local src="$1" dest="$2" _rec="$3"
    local bs="4M"
    $PV_ENABLED && dd if="$src" bs=$bs | pv | dd of="$dest" bs=$bs status=none || dd if="$src" of="$dest" bs=$bs status=progress
}

_copy_scp() {
    local src="$1" dest="$2" rec="$3"
    local flags=("-C" "-q")
    [[ "$rec" == true ]] && flags+=("-r")
    scp "${flags[@]}" "$src" "$dest"
}

_copy_ncp() {
    if ! command -v ncp >/dev/null; then err "ncp not installed"; return 1; fi
    ncp "$@"
}

_copy_sharing() { err "sharing cli not yet implemented"; return 1; }
_copy_cpy() { err "cpy-cli not yet implemented"; return 1; }

backend_dispatch() {
    local src="$1" dest="$2" rec="$3"
    case "$COPY_METHOD" in
        cp)       _copy_cp "$src" "$dest" "$rec" ;;
        rsync)    _copy_rsync "$src" "$dest" "$rec" ;;
        dd)       _copy_dd "$src" "$dest" "$rec" ;;
        scp)      _copy_scp "$src" "$dest" "$rec" ;;
        ncp)      _copy_ncp "$src" "$dest" "$rec" ;;
        sharing)  _copy_sharing "$src" "$dest" "$rec" ;;
        cpy|cpy-cli) _copy_cpy "$src" "$dest" "$rec" ;;
        *) err "Unsupported method $COPY_METHOD"; return 1;;
    esac
}

# =============================================================================
# Argument Parsing
# =============================================================================
parse_cli() {
    local arg op
    while [[ $# -gt 0 ]]; do
        arg="$1"; shift
        case "$arg" in
            -h|--help) print_usage; exit 0;;
            -v|--version) print_version; exit 0;;
            -d|--destination) DESTINATION="$(normalize_path "$1")"; shift;;
            -m|--method) COPY_METHOD="$1"; shift;;
            --pv) PV_ENABLED=true;;
            --no-pv) PV_ENABLED=false;;
            -p|--pattern) PATTERN_MODE=true;;
            -P|--parallel) PARALLEL_JOBS="$1"; shift;;
            --preserve) PRESERVE_ATTRS=true;;
            -f|--force) OVERWRITE_MODE="force";;
            -n|--no-overwrite) OVERWRITE_MODE="skip";;
            -b|--batch) BATCH_FILE="$1"; shift;;
            --) break;;
            -*) err "Unknown option $arg"; exit 1;;
            *) set -- "$arg" "$@"; break;;
        esac
    done
    SOURCES=("$@")
}

# =============================================================================
# Building Operation Queue
# =============================================================================
add_operation() {
    local src="$1" rec="$2" rename="$3"
    src="$(normalize_path "$src")"
    if $PATTERN_MODE; then
        local matched=(); IFS=$'\n' read -r -d '' -a matched < <(compgen -G "$src" && printf '\0') || true
        if [[ ${#matched[@]} -eq 0 ]]; then warn "Pattern $src matched nothing"; return; fi
        for m in "${matched[@]}"; do QUEUE_SRC+=("$m"); QUEUE_FLAGS+=("$rec"); QUEUE_DEST+=("$rename"); done
    else
        QUEUE_SRC+=("$src"); QUEUE_FLAGS+=("$rec"); QUEUE_DEST+=("$rename");
    fi
}

read_batch_file() {
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        eval set -- $line
        local src="" rec=false rename=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -R) rec=true; shift;;
                -r) rename="$2"; shift 2;;
                *) src="$1"; shift;;
            esac
        done
        add_operation "$src" "$rec" "$rename"
    done < "$BATCH_FILE"
}

interactive_input() {
    msg "Enter items to copy (blank line to finish):"
    while IFS= read -r -p "> " line; do
        [[ -z "$line" ]] && break
        eval set -- $line
        local src="" rec=false rename=""
        while [[ $# -gt 0 ]]; do
            case "$1" in -R) rec=true; shift;; -r) rename="$2"; shift 2;; *) src="$1"; shift;; esac
        done
        add_operation "$src" "$rec" "$rename"
    done
}

# =============================================================================
# Execution
# =============================================================================
execute_queue() {
    local total="${#QUEUE_SRC[@]}" idx=0 fail=0 ok=0
    msg "Starting transfers with method $COPY_METHOD (parallel=$PARALLEL_JOBS)"

    export -f backend_dispatch _copy_cp _copy_rsync _copy_dd _copy_scp _copy_ncp _copy_sharing _copy_cpy with_pv err PV_ENABLED PRESERVE_ATTRS OVERWRITE_MODE COPY_METHOD

    for i in "${!QUEUE_SRC[@]}"; do
        idx=$((i+1))
        src="${QUEUE_SRC[$i]}"; rename="${QUEUE_DEST[$i]}"; rec="${QUEUE_FLAGS[$i]}"
        dest="$DESTINATION"
        [[ -n "$rename" ]] && dest="$DESTINATION/$rename"
        if [[ -e "$dest" && "$OVERWRITE_MODE" == ask ]]; then
            confirm "Overwrite $dest?" || continue
        elif [[ -e "$dest" && "$OVERWRITE_MODE" == skip ]]; then
            warn "Skipping existing $dest"; continue
        fi
        printf '(%d/%d) ⏩ %s -> %s\n' "$idx" "$total" "$src" "$dest"
    done | (
        if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
            xargs -I{} -P "$PARALLEL_JOBS" bash -c '{ eval "$0"; }' "$BASH_SOURCE" backend_dispatch "$src" "$dest" "$rec"  # placeholder
        else
            while IFS= read -r line; do eval "$line"; done
        fi
    )
}

main() {
    parse_cli "$@"
    [[ -z "${DESTINATION:-}" ]] && { err "Destination required"; exit 1; }

    if [[ -n "$BATCH_FILE" ]]; then
        [[ ! -f "$BATCH_FILE" ]] && { err "Batch file $BATCH_FILE not found"; exit 1; }
        read_batch_file
    fi
    [[ ${#SOURCES[@]} -eq 0 && -z "$BATCH_FILE" ]] && interactive_input || for s in "${SOURCES[@]}"; do add_operation "$s" false ""; done

    [[ ${#QUEUE_SRC[@]} -eq 0 ]] && { err "No operations queued"; exit 0; }
    execute_queue
}

main "$@"


# =============================================================================
# Moverino - Advanced File and Directory Copy Tool
#
# Description: A flexible and interactive script for copying files and directories
#              with support for multiple copy methods and advanced options.
#
# Author:      flipflopsen
# Repository:  https://github.com/flipflopsen/LinToolsAndStuff
# License:     MIT
# Version:     2.0.0
# =============================================================================

set -o errexit   # Exit on any error
set -o nounset   # Exit if using undefined variables
set -o pipefail  # Catch failures in pipes

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

declare -a SOURCE_PATHS     # Array of source paths to copy
declare -a COPY_FLAGS       # Array of flags for each copy operation
declare -a TARGET_NAMES     # Array of target names (optional rename)

declare -r SCRIPT_NAME="${0##*/}"
declare -r VERSION="2.0.0"

# Default copy method (can be overridden by command line)
COPY_METHOD="cp"

# =============================================================================
# COPY METHOD IMPLEMENTATIONS
# =============================================================================

# Standard copy using cp
# Usage: _copy_with_cp <source> <destination> <is_recursive>
_copy_with_cp() {
    local src="$1"
    local dest="$2"
    local is_recursive="${3:-false}"
    
    local cp_flags=("-v")
    
    if [[ "$is_recursive" == "true" || -d "$src" ]]; then
        cp_flags+=("-a")  # Archive mode (recursive, preserve attributes)
    fi
    
    cp "${cp_flags[@]}" "$src" "$dest"
}

# RSYNC copy method (for future implementation)
# _copy_with_rsync() {
#     local src="$1"
#     local dest="$2"
#     local is_recursive="${3:-false}"
#     
#     local rsync_flags=("-av")
#     
#     if [[ "$is_recursive" != "true" ]]; then
#         rsync_flags+=("-d")  # Don't recurse
#     fi
#     
#     rsync "${rsync_flags[@]}" "$src" "$dest"
# }

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Print usage information
print_usage() {
    cat << EOF
$SCRIPT_NAME - Advanced File and Directory Copy Tool (v$VERSION)

Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -h, --help      Show this help message and exit
  -v, --version   Show version information and exit
  -m, --method    Copy method to use (default: cp)
                  Available methods: cp, rsync (rsync not yet implemented)

Interactive Mode:
  When run without arguments, the script enters interactive mode.
  Enter source paths one per line, with optional flags:
    -R, --recursive   Copy directories recursively
    -r, --rename NAME Rename the item at the destination

Examples:
  $ $SCRIPT_NAME
  $ $SCRIPT_NAME -m rsync

Report bugs to: <https://github.com/flipflopsen/LinToolsAndStuff/issues>
EOF
}

# Print version information
print_version() {
    echo "$SCRIPT_NAME v$VERSION"
}

# Validate and normalize a path
# Usage: normalize_path <path>
normalize_path() {
    local path="$1"
    # Expand tilde to home directory
    path="${path/#\~/$HOME}"
    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$PWD/$path"
    fi
    # Remove trailing slashes
    path="${path%%/}"
    echo "$path"
}

# Prompt for confirmation
# Usage: confirm <prompt> [default]
# Returns: 0 if yes, 1 if no
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -r -p "$prompt" response
    response="${response:-$default}"
    
    [[ "$response" =~ ^[yY](es)?$ ]]
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--version)
                print_version
                exit 0
                ;;
            -m|--method)
                COPY_METHOD="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                print_usage >&2
                exit 1
                ;;
        esac
    done
}

# Get source paths and options interactively
get_source_paths() {
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                FOLDER MOVER - INTERACTIVE MODE                    ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║ Type in the folders you want to copy, one per line.                ║"
    echo "║ Press Enter on a blank line when you are finished.                 ║"
    echo "║                                                                    ║"
    echo "║ Usage: <folder_path> [OPTIONS]                                     ║"
    echo "║   -R, --recursive   Copy directories recursively                   ║"
    echo "║   -r, --rename NAME Rename the item at the destination             ║"
    echo "║                                                                    ║"
    echo "║ Examples:                                                          ║"
    echo "║   /path/to/my_data -R                                              ║"
    echo "║   /path/to/another_folder                                          ║"
    echo "║   'folder with spaces' -R -r 'renamed folder'                      ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    
    while IFS= read -r -p "> " line; do
        [[ -z "$line" ]] && break
        
        local src_path=""
        local recursive=false
        local rename_path=""
        
        # Parse the input line
        eval set -- $line
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -R|--recursive)
                    recursive=true
                    shift
                    ;;
                -r|--rename)
                    rename_path="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                -*)
                    echo "Warning: Unknown option '$1'" >&2
                    shift
                    ;;
                *)
                    src_path="$1"
                    shift
                    # Process remaining arguments as part of the path if quoted
                    while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                        src_path+=" $1"
                        shift
                    done
                    ;;
            esac
        done
        
        if [[ -z "$src_path" ]]; then
            continue
        fi
        
        # Normalize and validate the source path
        src_path=$(normalize_path "$src_path")
        
        if [[ ! -e "$src_path" ]]; then
            echo "Warning: Source '$src_path' does not exist. Skipping." >&2
            continue
        fi
        
        # Store the operation details
        SOURCE_PATHS+=("$src_path")
        COPY_FLAGS+=("$recursive")
        TARGET_NAMES+=("$rename_path")
    done
}

# Get destination directory from user
get_destination() {
    local dest_dir=""
    
    while true; do
        read -r -p "Enter the destination directory: " dest_dir
        dest_dir=$(normalize_path "$dest_dir")
        
        if [[ -z "$dest_dir" ]]; then
            echo "Error: Destination cannot be empty." >&2
            continue
        fi
        
        if [[ ! -d "$dest_dir" ]]; then
            if confirm "Destination '$dest_dir' does not exist. Create it?" "y"; then
                mkdir -p "$dest_dir" || {
                    echo "Error: Failed to create destination directory." >&2
                    continue
                }
                break
            fi
        else
            break
        fi
    done
    
    echo "$dest_dir"
}

# Perform the copy operations
perform_copy_operations() {
    local dest_dir="$1"
    local success_count=0
    local fail_count=0
    
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                      COPY OPERATIONS                               ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║ Method: $COPY_METHOD"
    echo "║ Destination: $dest_dir" 
    echo "╚════════════════════════════════════════════════════════════════════╝"
    
    for i in "${!SOURCE_PATHS[@]}"; do
        local src="${SOURCE_PATHS[$i]}"
        local is_recursive="${COPY_FLAGS[$i]}"
        local rename="${TARGET_NAMES[$i]}"
        
        local target_path="$dest_dir"
        if [[ -n "$rename" ]]; then
            target_path="$dest_dir/$rename"
        fi
        
        echo -e "\n🔹 Copying: $src"
        echo "   → $target_path"
        
        # Select the appropriate copy method
        case "$COPY_METHOD" in
            cp)
                _copy_with_cp "$src" "$target_path" "$is_recursive"
                ;;
            # rsync)
            #     _copy_with_rsync "$src" "$target_path" "$is_recursive"
            #     ;;
            *)
                echo "❌ Error: Unknown copy method: $COPY_METHOD" >&2
                ((fail_count++))
                continue
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Success!"
            ((success_count++))
        else
            echo "❌ Error: Failed to copy '$src'." >&2
            ((fail_count++))
        fi
    done
    
    # Print summary
    echo -e "\n╔════════════════════════════════════════════════════════════════════╗"
    echo "║                      COPY SUMMARY                               ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║ Operations completed: $((success_count + fail_count))"
    echo "║   ✅ Success: $success_count"
    echo "║   ❌ Failed:  $fail_count"
    echo "╚════════════════════════════════════════════════════════════════════╝"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    parse_arguments "$@"
    
    # Interactive mode
    get_source_paths
    
    if [[ ${#SOURCE_PATHS[@]} -eq 0 ]]; then
        echo "No valid source paths were entered. Exiting." >&2
        exit 0
    fi
    
    local dest_dir
    dest_dir=$(get_destination)
    
    perform_copy_operations "$dest_dir"
}

# Run the main function
main "$@"

exit 0

