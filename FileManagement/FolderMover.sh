#!/bin/bash

# --- BASH SCRIPT TO INTERACTIVELY COPY FOLDERS ---
# This script prompts the user to enter a list of folders to copy,
# one per line. It supports flags for recursive copying and renaming.

# --- DATA STORAGE ---
# We use three parallel arrays to store the parsed information for each entry.
declare -a SOURCE_PATHS     # Array to store the source folder paths
declare -a IS_RECURSIVE   # Array to store the recursive flag (true/false)
declare -a TARGET_NAMES     # Array to store the new name if provided

# --- USER INSTRUCTIONS ---
echo "--------------------------------------------------------------------"
echo "Type in the folders you want to copy, one per line."
echo "Press Enter on a blank line when you are finished."
echo ""
echo "Usage: <folder_path> [-R] [-r new_name]"
echo "  -R          : Copy recursively (copies contents of the folder)."
echo "  -r new_name : Rename the folder at the destination."
echo ""
echo "Examples:"
echo "  /path/to/my_data -R"
echo "  /path/to/another_folder"
echo "  'folder with spaces' -R -r 'renamed folder'"
echo "--------------------------------------------------------------------"

# --- INPUT LOOP ---
# Read input line by line until an empty line is entered.
while IFS= read -r -p "> " line; do
  # Exit the loop if the user enters a blank line
  [[ -z "$line" ]] && break

  # Read the line into an array to easily separate the path from flags
  read -ra parts <<< "$line"
  
  # The first element is always the source path
  src_path="${parts[0]}"
  
  # Default values for flags
  recursive=false
  rename_path=""

  # Process the rest of the parts as flags (arguments)
  i=1
  while [[ $i -lt ${#parts[@]} ]]; do
    case "${parts[$i]}" in
      -R|--recursive)
        recursive=true
        ;;
      -r|--rename)
        # The next part is the new name for the folder
        ((i++))
        rename_path="${parts[$i]}"
        ;;
      *)
        echo "Warning: Unknown option '${parts[$i]}' for '$src_path'. Ignoring."
        ;;
    esac
    ((i++))
  done

  # Store the parsed details into our arrays
  SOURCE_PATHS+=("$src_path")
  IS_RECURSIVE+=("$recursive")
  TARGET_NAMES+=("$rename_path")
done

# --- CHECK IF ANY FOLDERS WERE ENTERED ---
if [ ${#SOURCE_PATHS[@]} -eq 0 ]; then
  echo "No folders were entered. Exiting."
  exit 0
fi

# --- PROMPT FOR DESTINATION ---
echo # Add a newline for better formatting
read -r -p "Enter the destination directory: " dest_dir

# Handle tilde expansion manually for robustness
dest_dir="${dest_dir/#\~/$HOME}"

# Validate that destination is not empty
if [[ -z "$dest_dir" ]]; then
  echo "Error: Destination directory cannot be empty. Aborting."
  exit 1
fi

# --- CREATE DESTINATION IF IT DOESN'T EXIST ---
if [[ ! -d "$dest_dir" ]]; then
  read -r -p "Destination '$dest_dir' does not exist. Create it? (y/N) " confirm
  if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
    # Create the directory, including parent directories if needed (-p)
    # Exit if creation fails
    mkdir -p "$dest_dir" || { echo "Error: Failed to create destination. Aborting."; exit 1; }
    echo "Destination created."
  else
    echo "Aborting."
    exit 0
  fi
fi

# --- EXECUTE COPY OPERATIONS ---
echo "--------------------------------------------------------------------"
echo "Starting copy process..."
echo "Destination: $dest_dir"
echo "--------------------------------------------------------------------"

success_count=0
fail_count=0

for i in "${!SOURCE_PATHS[@]}"; do
  src="${SOURCE_PATHS[$i]}"
  is_rec="${IS_RECURSIVE[$i]}"
  rename="${TARGET_NAMES[$i]}"

  # Check if the source path exists
  if [[ ! -e "$src" ]]; then
    echo "❌ Error: Source '$src' does not exist. Skipping."
    ((fail_count++))
    continue
  fi

  # Build the 'cp' command in an array for safety with spaces/special characters
  # Using -a (archive) is generally better than -r. It preserves permissions,
  # ownership, and timestamps, and is also recursive.
  cp_cmd=("cp")
  if [[ "$is_rec" == "true" ]]; then
    cp_cmd+=("-a")
  # If it's a directory and recursive flag is NOT set, 'cp' needs -r to work.
  # Let's add it automatically for convenience if the user forgot -R for a directory.
  elif [[ -d "$src" ]]; then
    cp_cmd+=("-a")
    echo "Info: Adding recursive flag for directory '$src'."
  fi

  # Determine the final target path
  target_path="$dest_dir"
  if [[ -n "$rename" ]]; then
    # If a rename is specified, append the new name to the destination
    target_path="$dest_dir/$rename"
  fi
  
  echo "🔹 Copying '$src' -> '$target_path'..."
  # Execute the command
  "${cp_cmd[@]}" "$src" "$target_path"

  # Check the exit status of the last command ($?)
  if [[ $? -eq 0 ]]; then
    echo "✅ Success!"
    ((success_count++))
  else
    echo "❌ Error: Failed to copy '$src'."
    ((fail_count++))
  fi
done

echo "--------------------------------------------------------------------"
echo "Process finished."
echo "✅ $success_count successful copies."
echo "❌ $fail_count failed copies."
echo "--------------------------------------------------------------------"

