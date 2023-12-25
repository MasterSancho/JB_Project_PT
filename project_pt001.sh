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

echo "Performing initial host discovery scan on $network_range..."
up_hosts=$(sudo nmap -sn $network_range | grep "Nmap scan report for" | cut -d ' ' -f 5)
echo "Hosts up in the network range:"
echo "$up_hosts"

echo "Enter the IP address you want to scan:"
read target_ip

echo "Choose scan type (basic/full):"
read scan_type

echo "Enter a name for the output directory:"
read output_dir

mkdir -p "$output_dir"  # Create the directory if it doesn't exist
output_file="$output_dir/scan_results.txt"

# Rest of the script for scanning the selected IP
if [ "$scan_type" == "basic" ]; then
    echo "Performing basic scan on $target_ip..."
    sudo nmap -sV $target_ip -oN $output_file
elif [ "$scan_type" == "full" ]; then
    echo "Performing full scan on $target_ip..."
    sudo nmap -sV --script=vuln -T4 $target_ip -oN $output_file
else
    echo "Invalid scan type selected. Exiting."
    exit 1
fi

echo "Scan complete. Results saved to $output_file."