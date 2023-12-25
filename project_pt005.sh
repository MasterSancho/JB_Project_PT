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

# Display available gateways and let the user choose one
echo "Available Gateways:"
IFS=$'\n' read -r -d '' -a gateways < <(route -n | grep 'UG[ \t]' | awk '{print $2}' && printf '\0')
for i in "${!gateways[@]}"; do
    echo "$((i+1))) ${gateways[i]}"
done

while true; do
    echo "Choose the number corresponding to the Gateway you want to use (or type 'exit' to quit):"
    read gateway_choice

    if [[ $gateway_choice == "exit" ]]; then
        echo "Exiting script."
        exit 0
    elif [[ $gateway_choice =~ ^[0-9]+$ ]] && [ $gateway_choice -ge 1 ] && [ $gateway_choice -le ${#gateways[@]} ]; then
        selected_gateway=${gateways[$((gateway_choice-1))]}
        break
    else
        echo "Invalid selection. Available Gateways:"
        for i in "${!gateways[@]}"; do
            echo "$((i+1))) ${gateways[i]}"
        done
        echo "Please choose a valid number from the list."
    fi
done

# Determine network range based on selected gateway
# Assuming a /24 subnet mask, modify if a different subnet mask is used
network_range="${selected_gateway%.*}.0/24"

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

echo "Choose the scan type:"
echo "1) basic"
echo "2) full"
read scan_choice

if [ "$scan_choice" == "1" ]; then
    scan_type="basic"
    echo "Performing basic scan on $target_ip..."
    sudo nmap -sV $target_ip >> $output_file
    sudo nmap -sU -T4 --version-light --min-rate 1000 --max-retries 1 -n -p U:53,67,68,69,88,123,137,138,161,162,389,500,514,1194,1701,1900,4500,5004,5005,5060,5061 -sV $target_ip >> $output_file
elif [ "$scan_choice" == "2" ]; then
    scan_type="full"
    echo "Performing full scan on $target_ip..."
    sudo nmap -sV --script=vuln -T4 $target_ip >> $output_file
    sudo nmap -sU -p U:53,67,68,69,88,123,137,138,161,162,389,500,514,1194,1701,1900,4500,5004,5005,5060,5061 -sV --script=vuln -T4 $target_ip >> $output_file  
else
    echo "Invalid scan type selected. Exiting."
    exit 1
fi

echo "Scan complete. Results saved to $output_file."
