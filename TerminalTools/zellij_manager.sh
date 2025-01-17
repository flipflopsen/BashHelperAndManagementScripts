#!/bin/bash

# Global Settings and Vars
program_base_folder="$HOME/.zellij_session_manager"
layout_folder="$program_base_folder/.zellij_layouts"  # Default location for layout files
session_file="$program_base_folder/zellij_session_manager_savefile.sav"
config_file="$program_base_folder/.zellij_session_manager_settings.conf"
session_file_enabled=false
attach_after_creation=false
declare -a sessions
declare -a zellij_layouts
# TODO: add declare -a layouts which saves all layouts from layout_folder with the key as the name without extension and the value as the absolute path of the file

# Save the zellij manager configuration
function save_configuration {
    echo "saving_enabled=$session_file_enabled" > "$config_file"
    echo "session_file_path=$session_file" >> "$config_file"
    echo "config_file_path=$config_file" >> "$config_file"
    echo "attach_after_creation=$attach_after_creation" >> "$config_file"
    echo "layout_folder=$layout_folder" >> "$config_file"
    echo "program_base_folder=$program_base_folder" >> "$config_file"
}

# Add a function to save sessions on terminal close
function save_on_exit {
    if [[ "$session_file_enabled" == "true" ]]; then
        echo "Saving sessions due to terminal close..."
        save_sessions
    fi
}

function set_config_file_path {
    read -p "Enter new configuration file path: " new_config_path
    if [[ -n "$new_config_path" ]]; then
        config_file="$new_config_path"
        echo "Configuration file path set to $config_file"
        save_configuration
    else
        echo "No path entered. Configuration file path remains unchanged."
    fi
    sleep 1
}

# Restore the zellij manager configuration
function restore_configuration {
    if [[ -e "$config_file" ]]; then
        source "$config_file"
        session_file_enabled=$( [[ "$saving_enabled" == "true" ]] && echo "true" || echo "false" )
        attach_after_creation=$( [[ "$attach_after_creation" == "true" ]] && echo "true" || echo "false" )
        echo "Configuration restored from $config_file"
    else
        echo "No configuration file found. Using default settings."
        session_file_enabled=false
        attach_after_creation=false
        config_file="$HOME/.zellij_session_manager_settings.conf"
        session_file="$HOME/.zellij_session_manager_savefile.sav"
        save_configuration
    fi
}

function toggle_session_saving {
    session_file_enabled=$( [[ "$session_file_enabled" == "true" ]] && echo "false" || echo "true" )
    echo "Session saving is now $( [[ "$session_file_enabled" == "true" ]] && echo "enabled" || echo "disabled")."
    save_configuration
    sleep 1
}

function set_session_file_path {
    read -p "Enter new session file path: " new_path
    if [[ -n "$new_path" ]]; then
        session_file="$new_path"
        echo "Session file path set to $session_file"
        save_configuration
    else
        echo "No path entered. Session file path remains unchanged."
    fi
    sleep 1
}

function set_layout_folder {
    read -p "Enter new layout folder path: " new_layout_folder
    if [[ -n "$new_layout_folder" ]]; then
        layout_folder="$new_layout_folder"
        echo "Layout folder path set to $layout_folder"
        save_configuration
    else
        echo "No path entered. Layout folder path remains unchanged."
    fi
    sleep 1
}

function set_program_base_folder {
    read -p "Enter new program base folder path: " new_program_base_folder
    if [[ -n "$new_program_base_folder" ]]; then
        program_base_folder="$new_program_base_folder"
        echo "Program base folder path set to $program_base_folder"
        save_configuration
    else
        echo "No path entered. Program base folder path remains unchanged."
    fi
    sleep 1
}

function toggle_attach_after_creation {
    attach_after_creation=$( [[ "$attach_after_creation" == "false" ]] && echo "true" || echo "false" )
    echo "Attach directly after creation is now $( [[ "$attach_after_creation" == "true" ]] && echo "enabled" || echo "disabled")."
    save_configuration
    sleep 1
}

function list_layouts {
    echo "Available Layouts:"

    if [[ -d "$layout_folder" ]]; then
        # Call the function to ensure zellij_layouts is populated
        scan_layout_folder

        # Check if there are any layouts to list
        if [ ${#zellij_layouts[@]} -eq 0 ]; then
            echo "-- No layouts available --"
        else
            # Initialize a counter for numbering
            local index=1
            for layout_name in "${!zellij_layouts[@]}"; do
                echo "$index. $layout_name"
                index=$((index + 1))
            done
        fi
    else
        echo "Layout folder does not exist. Please check the path: $layout_folder"
    fi

    sleep 1
}

function session_manager_configuration_menu {
    clear
    echo -e "\033[1;34mSession Manager Configuration\033[0m"
    echo "------------------------------"
    echo -e "1 - Toggle session save file [Currently: $( [[ "$session_file_enabled" == "true" ]] && echo -e '\033[32mEnabled\033[0m' || echo -e '\033[31mDisabled\033[0m')]"
    echo -e "2 - Toggle attach after session creation [Currently: $( [[ "$attach_after_creation" == "true" ]] && echo -e '\033[32mEnabled\033[0m' || echo -e '\033[31mDisabled\033[0m')]"
    echo ""
    echo -e "3 - Set session file path [Currently: $session_file]"
    echo -e "4 - Set configuration file path [Currently: $config_file]"
    echo -e "5 - Set layout folder path [Currently: $layout_folder]"
    echo -e "6 - Set program base folder path [Currently: $program_base_folder]"
    echo ""
    echo -e "7 - \033[0;33mReturn to Main Menu\033[0m"
    echo "------------------------------"
    read -p "Select option: " config_selection

    case $config_selection in
        1)
            toggle_session_saving
            session_manager_configuration_menu
            ;;
        2)
            toggle_attach_after_creation
            session_manager_configuration_menu
            ;;
        3)
            set_session_file_path
            session_manager_configuration_menu
            ;;
        4)
            set_config_file_path
            session_manager_configuration_menu
            ;;
        5)
            set_layout_folder
            session_manager_configuration_menu
            ;;
        6)
            set_program_base_folder
            session_manager_configuration_menu
            ;;
        7)
            ;; # Break the loop, return to main menu
        *)
            echo "Invalid option! Please try again."
            sleep 1
            session_manager_configuration_menu
            ;;
    esac
}

function save_sessions {
    echo "Session saving is not directly supported with Zellij." # Placeholder
    # Implement Zellij session saving logic if possible
}

function restore_sessions {
    if [[ -f "$session_file" && "$session_file_enabled" == "true" ]]; then
        echo "Restoring sessions from $session_file..."
        # Implement Zellij session restoration logic if possible
    else
        echo "Session file does not exist or session saving is disabled."
    fi
}

function attach_to_session {
    local session_input="$1"
    echo "Attaching to session $session_input." # Placeholder for attaching logic

    # Check if session_input is a number
    if [[ "$session_input" =~ ^[0-9]+$ ]]; then
        # It's a number, use it as an index to attach by session index
        echo "Attaching to session $session_input"
        zellij attach "${sessions[$session_input]}"
    else
        # It's not a number, treat it as a session name
        echo "Attaching to session $session_input"
        zellij attach "$session_input"
    fi
}

function refresh_sessions {
    mapfile -t sessions < <(zellij list-sessions 2>/dev/null)
}

function create_new_session {
    read -p "Enter new session name: " sname
    if [[ -z "$sname" ]]; then
        echo "Session name cannot be empty."
        return
    fi

    # Ensure layouts are scanned and available
    scan_layout_folder
    echo "Available Layouts:"
    local layout_names=()
    if [ ${#zellij_layouts[@]} -eq 0 ]; then
        echo "-- No layouts available --"
    else
        local index=1
        for layout_name in "${!zellij_layouts[@]}"; do
            echo "$index. $layout_name"
            layout_names+=("$layout_name")
            index=$((index + 1))
        done
    fi

    # Prompt user for a layout choice
    local layout_choice
    read -p "Enter a layout to use (leave empty for no layout): " layout_choice

    # Determine the chosen layout file
    local layout_file=""
    if [[ -n "$layout_choice" ]]; then
        if [[ "$layout_choice" =~ ^[0-9]+$ && "$layout_choice" -gt 0 && "$layout_choice" -le ${#layout_names[@]} ]]; then
            # User entered a valid number, use it as an index
            layout_file="${zellij_layouts[${layout_names[$((layout_choice - 1))]}]}"
        elif [[ -n "${zellij_layouts[$layout_choice]}" ]]; then
            # User entered a valid layout name
            layout_file="${zellij_layouts[$layout_choice]}"
        else
            echo "Invalid layout choice. Continuing without a layout."
        fi
    fi

    # Create the session with or without the layout
    if [[ -n "$layout_file" ]]; then
        zellij -l "$layout_file" -s "$sname"
        echo "Session '$sname' created with layout '${layout_names[$((layout_choice - 1))]}'."
    else
        zellij -s "$sname"
        echo "Session '$sname' created without a specific layout."
    fi

    # Attach to the session if configured to do so
    if [[ "$attach_after_creation" == "true" ]]; then
        zellij attach "$sname"
    fi

    save_sessions
}


function refresh_sessions {
  # Use a combination of tools to strip ANSI codes and isolate session names
  mapfile -t sessions < <(zellij list-sessions 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' | sed -E 's/^[^[:space:]]+[[:space:]]+//' | awk '{print $1}')
  # The pattern 's/^[^[:space:]]+[[:space:]]+//' removes headers or undesired text
}

function delete_session {
  # Refresh and display the list of sessions
  refresh_sessions
  display_sessions

  # Prompt the user for input
  read -p "Enter session number or name to delete: " session_input

  # Determine the correct session name to delete
  if [[ "$session_input" =~ ^[0-9]+$ ]] && (( session_input > 0 && session_input <= ${#sessions[@]} )); then
    session_to_delete="${sessions[$((session_input - 1))]}"
  else
    # Attempt to match session names directly
    session_to_delete=$(printf "%s\n" "${sessions[@]}" | grep -Fx "$session_input")
  fi

  session_formatted=$(echo "$session_to_delete" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}')

  # Check if the desired session to delete is found
  if [[ -n "$session_formatted" ]]; then
    zellij kill-session "$session_formatted"
    echo "Session '$session_formatted' has been deleted."
  else
    echo "No session named '$session_input' found."
  fi

  save_sessions
  display_sessions
}

function rename_session {
    echo "Zellij does not support renaming sessions out-of-the-box yet."
    # Implement logic as needed based on Zellij's updates or features
}

function process_input {
    read -p "Selection: " input
    case "$input" in
        [1-9]*)
            attach_to_session "$input"
            ;;
        [Aa])
            read -p "Enter session name or number to attach: " session_name
            attach_to_session "$session_name"
            ;;
        [Cc])
            create_new_session
            ;;
        [Rr])
            rename_session
            ;;
        [Dd])
            delete_session
            ;;
        [Ss])
            session_manager_configuration_menu
            ;;
        [Ll][Ll])
            list_layouts
            ;;
        [Xx])
            exit
            ;;
        *)
            attach_to_session "$input"
            ;;
    esac
}

echo -e "--------------------------------------"

function display_header {
    local title="$1"
    echo -e "\n\033[1;34m$title\033[0m"
    echo -e "--------------------------------------\n"
}

function display_subheader {
    local title="$1"
    echo -e "\n\033[1;36m$title\033[0m:"
}

function display_commands {
    echo -e "\033[0;33mC\033[0m - Create a new session"
    echo -e "\033[0;33mA\033[0m - Attach to an existing session"
    echo -e "\033[0;33mR\033[0m - Rename an existing session"
    echo -e "\033[0;33mD\033[0m - Delete a session"
    echo -e "\033[0;33mS\033[0m - Session Manager Configuration"
    echo -e "\033[0;33mLL\033[0m - List available layouts"
    echo -e "\033[0;33mX\033[0m - Exit\n"
}

function display_sessions {
    clear
    display_header "Zellij Session Manager - by flipflopsen"

    if [[ "$session_file_enabled" == "true" ]]; then
        echo -e "Session file: $session_file [\033[32mEnabled\033[0m]\n"
    else
        echo -e "Session file: $session_file [\033[31mDisabled\033[0m]\n"
    fi

    mapfile -t sessions < <(zellij list-sessions 2>/dev/null)
    display_subheader "Available Sessions"
    if [ ${#sessions[@]} -eq 0 ]; then
        echo "-- No active sessions --"
    else
        for i in "${!sessions[@]}"; do
            echo -e "\033[32m$((i + 1))\033[0m. ${sessions[i]}"
        done
    fi

    display_subheader "Commands"
    display_commands
    echo -e "\033[1;33mSelect an option:\033[0m"
}
function ensure_base_folder_and_files {
    # Check and create program base folder if it doesn't exist
    if [[ ! -d "$program_base_folder" ]]; then
        echo "Creating program base folder at $program_base_folder"
        mkdir -p "$program_base_folder"
    fi

    # Check and create layout folder if it doesn't exist
    if [[ ! -d "$layout_folder" ]]; then
        echo "Creating layout folder at $layout_folder"
        mkdir -p "$layout_folder"
    fi

    # Check and create session file if it doesn't exist
    if [[ ! -f "$session_file" ]]; then
        echo "Creating session file $session_file"
        touch "$session_file"
    fi

    # Check and create configuration file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        echo "Creating configuration file $config_file"
        touch "$config_file"
    fi
}

function scan_layout_folder {
    if [[ -d "$layout_folder" ]]; then
        # Iterate over all .kdl files in the layout folder
        while IFS= read -r -d '' file; do
            filename=$(basename "$file" .kdl)
            zellij_layouts["$filename"]="$file"  # Populate the dictionary
        done < <(find "$layout_folder" -maxdepth 1 -type f -name "*.kdl" -print0)
    else
        echo "Layout folder does not exist. Please check the path: $layout_folder"
    fi
}


trap save_on_exit SIGHUP

# Entry point
ensure_base_folder_and_files
scan_layout_folder
restore_configuration
if [[ "$session_file_enabled" == "true" ]]; then
    restore_sessions
fi

while true; do
    refresh_sessions
    display_sessions
    process_input
done
