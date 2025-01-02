#!/bin/bash

# Global Settings and Vars
session_file="$HOME/.tmux_session_manager_savefile.sav"
config_file="$HOME/.tmux_session_manager_settings.conf"
session_file_enabled=false
attach_after_creation=false
declare -a sessions

# Save the tmux manager configuration
function save_configuration {
    echo "saving_enabled=$session_file_enabled" > "$config_file"
    echo "session_file_path=$session_file" >> "$config_file"
    echo "config_file_path=$config_file" >> "$config_file"
    echo "attach_after_creation=$attach_after_creation" >> "$config_file"
}

# Add a function to save sessions on terminal close
function save_on_exit {
    if [[ "$session_file_enabled" == "true" ]]; then
        echo "Saving sessions due to terminal close..."
        save_sessions
    fi
}

# Sets the config file path (in options menu)
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

# Restore the tmux manager configuration
function restore_configuration {
    if [[ -e "$config_file" ]]; then
        source "$config_file"
        [ "$saving_enabled" == "true" ] && session_file_enabled=true || session_file_enabled=false
        [ "$attach_after_creation" == "true" ] && attach_after_creation=true || attach_after_creation=false
        echo "Configuration restored from $config_file"
    else
        echo "No configuration file found. Using default settings."
        session_file_enabled=false
        attach_after_creation=false
        config_file="$HOME/.tmux_session_manager_settings.conf"
        session_file="$HOME/.tmux_session_manager_savefile.sav"
        save_configuration
    fi
}

# Toggle session saving on or off
function toggle_session_saving {
    if [ "$session_file_enabled" = true ]; then
        session_file_enabled=false
    else
        session_file_enabled=true
    fi
    echo "Session saving is now $( [[ "$session_file_enabled" = true ]] && echo "enabled" || echo "disabled")."
    save_configuration  # Save configuration after updating
    sleep 1
}

# Set the session file path
function set_session_file_path {
    read -p "Enter new session file path: " new_path
    if [[ -n "$new_path" ]]; then
        session_file="$new_path"
        echo "Session file path set to $session_file"
        save_configuration  # Save configuration after updating
    else
        echo "No path entered. Session file path remains unchanged."
    fi
    sleep 1
}

function toggle_attach_after_creation {
    attach_after_creation=$([[ "$attach_after_creation" == "false" ]] && echo "true" || echo "false")
    echo "Attach directly after creation is now $( [[ "$attach_after_creation" == "true" ]] && echo "enabled" || echo "disabled")."
    save_configuration
    sleep 1
}

function session_manager_configuration_menu {
    clear
    echo -e "\033[1;34mSession Manager Configuration\033[0m|"
    echo "------------------------------"
    echo -e "1 - Toggle session save file [Currently: $( [[ "$session_file_enabled" == "true" ]] && echo -e '\033[32mEnabled\033[0m' || echo -e '\033[31mDisabled\033[0m')]"
    echo -e "2 - Toggle attach after session creation [Currently: $( [[ "$attach_after_creation" == "true" ]] && echo -e '\033[32mEnabled\033[0m' || echo -e '\033[31mDisabled\033[0m')]"
    echo ""
    echo -e "3 - Set session file path [Currently: $session_file]"
    echo -e "4 - Set configuration file path [Currently: $config_file]"
    echo ""
    echo -e "5 - \033[0;33mReturn to Main Menu\033[0m"
    echo "-----------------------"
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
            ;; # Break the loop, return to main menu
        *)
            echo "Invalid option! Please try again."
            sleep 1
            session_manager_configuration_menu
            ;;
    esac
}


# Save session configuration to file
function save_sessions {
    if [ "$session_file_enabled" = true ]; then
        # Start of JSON array
        echo "[" > "$session_file"
        
        tmux list-sessions -F '#{session_id} #{session_name}' | while read -r session_id session_name; do
            echo "{\"session_name\": \"$session_name\", \"windows\": [" >> "$session_file"
            
            # Iterate over each window in the session
            tmux list-windows -t "$session_id" -F '#{window_id} #{window_name}' | while read -r window_id window_name; do
                echo "{\"window_name\": \"$window_name\", \"panes\": [" >> "$session_file"
                
                # Iterate over each pane in the window
                tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_current_path}' | while read -r pane_id pane_path; do
                    echo "{\"pane_id\": \"$pane_id\", \"path\": \"$pane_path\"}," >> "$session_file"
                done
                
                # Remove the last comma and close the JSON array for panes
                sed -i '$ s/,$//' "$session_file"
                echo "] }," >> "$session_file"
            done
            
            # Remove the last comma and close the JSON array for windows
            sed -i '$ s/,$//' "$session_file"
            echo "] }," >> "$session_file"
        done
        
        # Remove the last comma and close the JSON array for sessions
        sed -i '$ s/,$//' "$session_file"
        echo "]" >> "$session_file"
    fi
}

# Restore sessions at startup
function restore_sessions {
    if [[ -f "$session_file" && "$session_file_enabled" = true ]]; then
        echo "Restoring sessions from $session_file..."
        jq -c '.[]' "$session_file" | while IFS= read -r session_json; do
            session_name=$(echo "$session_json" | jq -r '.session_name')
            # Create the session without attaching
            tmux new-session -d -s "$session_name"
            echo "$session_json" | jq -c '.windows[]' | while IFS= read -r window_json; do
                window_name=$(echo "$window_json" | jq -r '.window_name')
                first_pane=1
                echo "$window_json" | jq -c '.panes[]' | while IFS= read -r pane_json; do
                    pane_path=$(echo "$pane_json" | jq -r '.path')
                    if [[ $first_pane -eq 1 ]]; then
                        # For the first pane, simply move to its directory.
                        tmux send-keys -t "$session_name:$window_name" "cd $pane_path" C-m
                        first_pane=0
                    else
                        # Create new pane and move to directory.
                        tmux split-window -t "$session_name:$window_name"
                        tmux send-keys -t "$session_name:$window_name" "cd $pane_path" C-m
                    fi
                done
                # Set up layout and set active window correctly.
                tmux select-layout -t "$session_name:$window_name" tiled
                tmux select-window -t "$session_name:$window_name"
            done
        done
    else
        echo "Session file does not exist or session saving is disabled."
    fi
}

# Attach to an existing session by number or name
function attach_to_session {
    local session_input="$1"
    
    # Check if input is numeric and within the range of available sessions
    if [[ "$session_input" =~ ^[0-9]+$ ]] && (( session_input > 0 && session_input <= ${#sessions[@]} )); then
        # Input is numeric, use it as an index (arrays are zero-indexed)
        tmux attach-session -t "${sessions[$((session_input-1))]}"
    else
        # Not a number or out of range, try to attach using the input as a session name
        if tmux has-session -t "$session_input" 2>/dev/null; then
            tmux attach-session -t "$session_input"
        else
            # If tmux has-session command fails, it's an invalid session identifier
            echo "Invalid selection. Please choose a command from the list or enter a valid session identifier."
            read -p "Press any key to continue..."
        fi
    fi
}


function refresh_sessions {
    mapfile -t sessions < <(tmux list-sessions -F '#S' 2>/dev/null)
}


# Create a new session without attaching
function create_new_session {
    read -p "Enter new session name: " sname
    if [ -z "$sname" ]; then
        echo "Session name cannot be empty."
        return
    fi
    
    tmux new-session -d -s "$sname"
    echo "Session '$sname' created."
    save_sessions
    if [[ "$attach_after_creation" == "true" ]]; then
        tmux attach-session -t "$sname"
    fi
}

# Function to delete a session
function delete_session {
    display_sessions # Display current sessions to choose from
    read -p "Enter session number or name to delete: " session_to_delete
    if [[ "$session_to_delete" =~ ^[0-9]+$ ]] && (( session_to_delete > 0 && session_to_delete <= ${#sessions[@]} )); then
        session_to_delete=${sessions[$((session_to_delete-1))]}
    fi

    if tmux has-session -t "$session_to_delete" 2>/dev/null; then
        tmux kill-session -t "$session_to_delete"
        echo "Session '$session_to_delete' has been deleted."
        save_sessions  # Update the session save file
    else
        echo "Session '$session_to_delete' was not found."
    fi
    sleep 1
}

# Function to rename an existing session
function rename_session {
    display_sessions # Display current sessions to choose from
    read -p "Enter session number or current name to rename: " session_to_rename
    if [[ "$session_to_rename" =~ ^[0-9]+$ ]] && (( session_to_rename > 0 && session_to_rename <= ${#sessions[@]} )); then
        session_to_rename=${sessions[$((session_to_rename-1))]}
    fi

    if tmux has-session -t "$session_to_rename" 2>/dev/null; then
        read -p "Enter new session name: " new_session_name
        tmux rename-session -t "$session_to_rename" "$new_session_name"
        echo "Session '$session_to_rename' has been renamed to '$new_session_name'."
        save_sessions  # Update the session save file
    else
        echo "Session '$session_to_rename' was not found."
    fi
    sleep 1
}

# Handle main input processing
function process_input {
    read -p "Selection: " input
    case "$input" in
        [1-9]*) # Numeric input for quick attach
            attach_to_session "$input"
            ;;
        [Aa]) # Attach to session by name
            read -p "Enter session name or number to attach: " session_name
            attach_to_session "$session_name"
            ;;
        [Cc]) # Create new session
            create_new_session
            ;;
        [Rr]) # Rename a session
            rename_session
            ;;
        [Dd]) # Delete a session
            delete_session
            ;;
        [Ss]) # Open config menu
            session_manager_configuration_menu
            ;;
        [Xx]) # Exit script
            exit
            ;;
        *) 
            # in this case maybe the user tries to attach via the name of the session.
            # exception handling for that is now in attach function
            attach_to_session "$input"
            ;;
    esac
}

echo -e "--------------------------------------"

function display_header {
    local title="$1"
    echo -e "\n\033[1;34m$title\033[0m"  # Blue bold formatting with added new lines for spacing
    echo -e "--------------------------------------\n"
}

function display_subheader {
    local title="$1"
    echo -e "\n\033[1;36m$title\033[0m:"  # Cyan color for subsection titles
}

# Function to display command options
function display_commands {
    echo -e "\033[0;33mC\033[0m - Create a new session"
    echo -e "\033[0;33mA\033[0m - Attach to an existing session"
    echo -e "\033[0;33mR\033[0m - Rename an existing session"
    echo -e "\033[0;33mD\033[0m - Delete a session"
    echo -e "\033[0;33mS\033[0m - Session Manager Configuration"
    echo -e "\033[0;33mX\033[0m - Exit\n"
}

function display_sessions {
    clear
    display_header "TMUX Session Manager - by flipflopsen"
    
    if [[ "$session_file_enabled" == "true" ]]; then
        echo -e "Session file: $session_file [\033[32mEnabled\033[0m]\n"
    else
        echo -e "Session file: $session_file [\033[31mDisabled\033[0m]\n"
    fi

    mapfile -t sessions < <(tmux list-sessions -F '#S' 2>/dev/null)
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
    echo -e "\033[1;33mSelect an option:\033[0m"  # Bold yellow text for selection prompt
}

trap save_on_exit SIGHUP

# Entry point
restore_configuration
if [[ "$session_file_enabled" == "true" ]]; then
    restore_sessions
fi

while true; do
    refresh_sessions
    display_sessions
    process_input
done