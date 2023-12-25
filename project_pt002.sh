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
IFS=$'\n' read -r -d '' -a up_hosts < <(sudo nmap -sn $network_range | grep "Nmap scan report for" | cut -d ' ' -f 5 && printf '\0')
echo "Hosts up in the network range:"
for i in "${!up_hosts[@]}"; do
    echo "$((i+1))) ${up_hosts[i]}"
done

echo "Choose the number corresponding to the IP address you want to scan:"
read choice
target_ip=${up_hosts[$((choice-1))]}

# Set the output directory name to the chosen IP address
output_dir="$target_ip"
mkdir -p "$output_dir"
echo "Output directory created: $output_dir"
output_file="$output_dir/scan_results.txt"

echo "Choose scan type: 1 for basic, 2 for full"
read scan_choice

if [ "$scan_choice" == "1" ]; then
    scan_type="basic"
    echo "Performing basic scan on $target_ip..."
    sudo nmap -sV $target_ip -oN $output_file
elif [ "$scan_choice" == "2" ]; then
    scan_type="full"
    echo "Performing full scan on $target_ip..."
    sudo nmap -sV --script=vuln -T4 $target_ip -oN $output_file
else
    echo "Invalid scan type selected. Exiting."
    exit 1
fi

echo "Scan complete. Results saved to $output_file."
