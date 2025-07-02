#!/bin/bash
# login_menu.sh - Custom login popup for specific user

# Define your custom commands for each option
command1() {
  # Replace with your custom command for option 1
  echo "Normal \& Uni"
  # Example: gnome-terminal &
}

command2() {
  # Replace with your custom command for option 2
  echo "Cybersecurity"
  # Example: nautilus ~/Documents &
}

command3() {
  # Replace with your custom command for option 3
  echo "Surfing"
  # Example: firefox --new-window https://example.com &
}

command3() {
  echo "Surfing"
}



choice=$(dialog --clear \
                --backtitle "Login Menu" \
                --title "Select Action" \
                --menu "Choose an option:" \
                15 40 3 \
                1 "Option 1 Description" \
                2 "Option 2 Description" \
                3 "Option 3 Description" \
                2>&1 >/dev/tty)

# Handle selection
case $choice in
  1) command1 ;;
  2) command2 ;;
  3) command3 ;;
  *) echo "Action cancelled" ;;
esac

clear
exit 0

