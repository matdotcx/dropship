#!/bin/bash

# Terminal colors and formatting
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color
BOLD="\e[1m"

# Get terminal width
TERM_WIDTH=$(tput cols)

# Spinner characters
SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Pretty print function
pretty_print() {
    local message="$1"
    local symbol="$2"
    local color="$3"
    printf "${color}${symbol} ${message}${NC}\n"
}

printf "\e[1m>> Dropship Installation Script\e[0m\n"
printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -

# Check if script is run with sudo
if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] Please do not run this script with sudo"
    exit 1
fi

# Create installation directory if it doesn't exist
echo "[INFO] Creating installation directory..."
sudo mkdir -p /usr/local/bin

# Create the dropship script with JSON support
echo "[INFO] Creating dropship script..."
cat > /tmp/dropship << 'EOF'
#!/bin/bash

# Terminal colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get terminal width
TERM_WIDTH=$(tput cols)

# Pretty print function
pretty_print() {
    printf "${3}${2} ${1}${NC}\n"
}

# Spinner array
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_INDEX=0

# Progress display function
show_progress() {
    local percent=$1
    local filename=$2
    local speed=$3
    local eta=$4
    
    # Update spinner
    local spinner=${SPINNER_FRAMES[$SPINNER_INDEX]}
    SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % ${#SPINNER_FRAMES[@]} ))
    
    # Clear line and show progress with colors
    printf "\r\033[K${BLUE}%s${NC} ${GREEN}%3d%%${NC} ${YELLOW}%s${NC}" "$spinner" "$percent" "$filename"
    
    # If speed and eta are provided, show them
    if [[ -n "$speed" && -n "$eta" ]]; then
        printf " ${BLUE}(%s, %s)${NC}" "$speed" "$eta"
    fi
}

# Function to parse JSON using Python
get_server_info() {
    local tag="$1"
    local config_file="$HOME/.dropship.json"
    python3 -c "
import json, sys
with open('$config_file', 'r') as f:
    config = json.load(f)
for server in config['servers']:
    if server['tag'] == '$tag':
        print(f'{server[\"user\"]} {server[\"host\"]} {server[\"path\"]}'.strip())
        sys.exit(0)
sys.exit(1)
"
}

get_default_server() {
    local config_file="$HOME/.dropship.json"
    python3 -c "
import json
with open('$config_file', 'r') as f:
    config = json.load(f)
print(config['default'])
"
}

list_servers() {
    local config_file="$HOME/.dropship.json"
    python3 -c "
import json
with open('$config_file', 'r') as f:
    config = json.load(f)
print('\nConfigured servers:')
for server in config['servers']:
    print(f'  {server[\"tag\"]}: {server[\"host\"]}')
"
}

# Function to show usage
usage() {
    echo "Usage: dropship [-d server_tag] <path/to/file/or/folder>"
    echo "Options:"
    echo "  -d    Specify destination server by tag"
    echo "  -h    Show this help message"
    if [ -f ~/.dropship.json ]; then
        list_servers
    fi
    exit 1
}

# Check for help flag immediately
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Check if config exists
if [ ! -f ~/.dropship.json ]; then
    echo "Error: ~/.dropship.json configuration file not found"
    exit 1
fi

# Initialize variables
target_tag=$(get_default_server)
path=""

# Parse command line options
while getopts "d:h" opt; do
    case $opt in
        d)
            target_tag="${OPTARG}"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            ;;
    esac
done

# Shift to the path argument
shift $((OPTIND-1))

# Check if path argument is provided
if [ -z "$1" ]; then
    echo "Error: No path provided"
    usage
fi

path="$1"

# Check if path exists
if [ ! -e "$path" ]; then
    echo "Error: Path '$path' does not exist"
    exit 1
fi

# Get server information
server_info=$(get_server_info "$target_tag")
if [ $? -ne 0 ]; then
    echo "Error: Server with tag '$target_tag' not found"
    exit 1
fi

# Parse server info
read -r user host dest_path <<< "$server_info"

# Show transfer destination
echo -e "${BLUE}>> Starting transfer to $user@$host:$dest_path${NC}"

# Get the base name of the source
src_basename=$(basename "$path")

# Spinner array
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_INDEX=0

# Progress bar function with spinner
draw_progress_bar() {
    local width=$((TERM_WIDTH - 25)) # Adjusted width to accommodate spinner
    local percent=$1
    local completed=$((width * percent / 100))
    local remaining=$((width - completed))
    
    # Update spinner
    local spinner=${SPINNER_FRAMES[$SPINNER_INDEX]}
    SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % ${#SPINNER_FRAMES[@]} ))
    
    printf "\r$spinner ["
    printf "%${completed}s" | tr ' ' '='
    printf ">"
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
}

# Format size function
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        printf "%.1fG" $(echo "scale=1; $size/1073741824" | bc)
    elif [ $size -ge 1048576 ]; then
        printf "%.1fM" $(echo "scale=1; $size/1048576" | bc)
    elif [ $size -ge 1024 ]; then
        printf "%.1fK" $(echo "scale=1; $size/1024" | bc)
    else
        printf "%dB" $size
    fi
}

# Simple rsync wrapper with progress
rsync_with_progress() {
    local source=$1
    local dest=$2
    
    pretty_print "Starting transfer..." ">>" "$BLUE"
    
    # Use standard rsync progress
    rsync -ah --progress "$source" "$dest" 2>&1 | {
        local current_file=""
        local current=0
        local speed=""
        local eta=""
        
        while IFS= read -r line; do
            # Extract current file name
            if [[ $line =~ ^[[:space:]]*([^[:space:]]+/[^[:space:]]+) ]]; then
                current_file="${BASH_REMATCH[1]}"
            fi
            
            # Extract progress percentage
            if [[ $line =~ ([0-9]+)% ]]; then
                current=${BASH_REMATCH[1]}
            fi
            
            # Extract speed and ETA
            if [[ $line =~ ([0-9.]+[[:space:]]*[kMG]?B/s)[[:space:]]+([0-9:]+) ]]; then
                speed="${BASH_REMATCH[1]}"
                eta="${BASH_REMATCH[2]}"
            fi
            
            # Show progress if we have a file and it's not just a directory
            if [[ -n "$current_file" && "$current_file" != "./" && "$current_file" != *"/" ]]; then
                show_progress "$current" "$current_file" "$speed" "$eta"
            fi
        done
        echo # New line after progress
    }
}

# Enhanced rsync flags for better progress display
RSYNC_FLAGS="-ah --info=progress2 --no-inc-recursive"

# Function to check if path exists on remote
check_remote_path() {
    local user="$1"
    local host="$2"
    local path="$3"
    local basename="$4"

    if ssh "$user@$host" "test -e '$path/$basename'"; then
        return 0  # Path exists
    else
        return 1  # Path does not exist
    fi
}

# Function to find next available increment
find_next_increment() {
    local user="$1"
    local host="$2"
    local path="$3"
    local basename="$4"
    local extension="${basename##*.}"
    local filename="${basename%.*}"
    local counter=1

    if [[ "$basename" != *.* ]]; then
        # No extension
        filename="$basename"
        extension=""
    fi

    while true; do
        if [[ -n "$extension" ]]; then
            test_name="${filename}_${counter}.${extension}"
        else
            test_name="${filename}_${counter}"
        fi

        if ! ssh "$user@$host" "test -e '$path/$test_name'"; then
            echo "$test_name"
            return 0
        fi
        ((counter++))
    done
}

# Check SSH connectivity first before attempting transfer
echo "Starting transfer to $user@$host:$dest_path"
echo

# Test SSH connection first
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$user@$host" "echo 'Connection successful'"; then
    echo -e "${RED}[ERROR] Cannot connect to $host: SSH connection failed${NC}"
    exit 1
fi

if [ -d "$path" ]; then
    # If it's a directory, check if it exists
    if check_remote_path "$user" "$host" "$dest_path" "${src_basename}"; then
        printf "${YELLOW}[WARN] Directory '$src_basename' already exists at destination${NC}\n"
        printf "${BLUE}Options:${NC}\n"
        printf "  [u] Update existing files\n"
        printf "  [c] Create new copy with increment (e.g. folder_1)\n"
        printf "  [n] Cancel transfer\n"
        read -p "Choose an option [u/c/N]: " choice
        case "$choice" in
            [Uu])
                rsync_with_progress "${path%/}/" "$user@$host:$dest_path/${src_basename}/"
                ;;
            [Cc])
                new_name=$(find_next_increment "$user" "$host" "$dest_path" "${src_basename}")
                echo "Creating new copy as: $new_name"
                rsync_with_progress "${path%/}/" "$user@$host:$dest_path/${new_name}/"
                ;;
            *)
                echo "Transfer cancelled"
                exit 0
                ;;
        esac
    else
        rsync_with_progress "${path%/}/" "$user@$host:$dest_path/${src_basename}/"
    fi
else
    # If it's a file, check if it exists
    if check_remote_path "$user" "$host" "$dest_path" "$(basename "$path")"; then
        echo "[WARN] File '$(basename "$path")' already exists at destination"
        echo "Options:"
        echo "  [u] Update existing file"
        echo "  [c] Create new copy with increment (e.g. file_1.txt)"
        echo "  [n] Cancel transfer"
        read -p "Choose an option [u/c/N]: " choice
        case "$choice" in
            [Uu])
                rsync_with_progress "$path" "$user@$host:$dest_path/"
                if [ "$list_after" = true ]; then
                    list_remote_contents "$user" "$host" "$dest_path" "$(basename "$path")"
                fi
                ;;
            [Cc])
                new_name=$(find_next_increment "$user" "$host" "$dest_path" "$(basename "$path")")
                echo -e "${GREEN}Creating new copy as: $new_name${NC}"
                rsync_with_progress "$path" "$user@$host:$dest_path/$new_name"
                if [ "$list_after" = true ]; then
                    list_remote_contents "$user" "$host" "$dest_path" "$new_name"
                fi
                ;;
            *)
                echo -e "${YELLOW}Transfer cancelled${NC}"
                exit 0
                ;;
        esac
    else
        rsync_with_progress "$path" "$user@$host:$dest_path/"
        if [ "$list_after" = true ]; then
            list_remote_contents "$user" "$host" "$dest_path" "$(basename "$path")"
        fi
    fi
fi

transfer_status=$?

if [ $transfer_status -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Transfer completed successfully${NC}"
    exit 0
else
    echo -e "${RED}[ERROR] Transfer failed with status: $transfer_status${NC}"
    exit 1
fi
EOF

# Install dropship script
echo "Installing dropship script..."
sudo mv /tmp/dropship /usr/local/bin/
sudo chmod +x /usr/local/bin/dropship
echo "Dropship script installed to /usr/local/bin/dropship"

# SSH Key Setup
echo "[INFO] Setting up SSH keys..."

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Check if SSH key already exists
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "SSH key already exists at ~/.ssh/id_ed25519"
    read -p "Generate new key anyway? (y/n): " generate_new
    if [[ $generate_new != "y" ]]; then
        existing_key=true
    fi
fi

if [[ $existing_key != true ]]; then
    # Get email for key comment
    read -p "Enter your email address: " email

    # Generate new ED25519 key
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519
fi

chmod 600 ~/.ssh/id_ed25519

# Server configuration function
add_server() {
    echo "--- Server Configuration ---"
    read -p "Enter server tag (e.g., webhost-primary): " server_tag
    read -p "Enter server username: " server_user
    read -p "Enter server hostname: " server_host
    read -p "Enter server destination path (press Enter for home directory): " server_path

    # Use home directory if no path provided
    if [ -z "$server_path" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            server_path="/Users/$server_user"
        else
            server_path="/home/$server_user"
        fi
        echo "Using default path: $server_path"
    fi

    # Create/Update JSON configuration
    python3 - <<END
import json
import os

config = {
    'default': '$server_tag',
    'servers': [{
        'tag': '$server_tag',
        'user': '$server_user',
        'host': '$server_host',
        'path': '$server_path'
    }]
}

with open(os.path.expanduser('~/.dropship.json'), 'w') as f:
    json.dump(config, f, indent=2)
END

    # Test SSH connection and create directory
    echo "Testing SSH connection and creating directory..."
    if ssh -q "$server_user@$server_host" "mkdir -p $server_path"; then
        echo "[SUCCESS] SSH connection and directory creation successful!"
        return 0
    else
        echo "[ERROR] SSH connection failed. Please check your credentials."
        return 1
    fi
}

# Check for command line arguments
while getopts "n" opt; do
    case $opt in
        n)
            pretty_print "Adding new server configuration..." ">>" "$BLUE"
            add_server
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

# Only run initial configuration if dropship.json doesn't exist
config_file="$HOME/.dropship.json"
if [ ! -f "$config_file" ]; then
    pretty_print "Initial server configuration..." ">>" "$BLUE"
    add_server

    # Ask if user wants to add more servers
    while true; do
        read -p "Would you like to add another server? (y/n): " add_more
        if [[ $add_more != "y" ]]; then
            break
        fi

    # For additional servers, we'll need to append to existing config
    echo "--- Additional Server Configuration ---"
    read -p "Enter server tag (e.g., webhost-primary): " server_tag
    read -p "Enter server username: " server_user
    read -p "Enter server hostname: " server_host
    read -p "Enter server destination path (press Enter for home directory): " server_path

    if [ -z "$server_path" ]; then
        server_path="/home/$server_user"
        echo "Using default path: $server_path"
    fi

    python3 - <<END
import json
import os

config_file = os.path.expanduser('~/.dropship.json')
with open(config_file, 'r') as f:
    config = json.load(f)

config['servers'].append({
    'tag': '$server_tag',
    'user': '$server_user',
    'host': '$server_host',
    'path': '$server_path'
})

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
END

    # Test connection for additional server
    echo "Testing SSH connection and creating directory..."
    if ! ssh -q "$server_user@$server_host" "mkdir -p $server_path"; then
        echo "[ERROR] SSH connection failed for $server_tag"
    else
        echo "[SUCCESS] SSH connection successful!"
    fi
done

# Close the if block for initial configuration
fi

# Show final configuration
echo
pretty_print "Final Configuration:" ">>" "$BLUE"
python3 - <<END
import json
import os

with open(os.path.expanduser('~/.dropship.json'), 'r') as f:
    config = json.load(f)

print(f"\nDefault server: {config['default']}\n")
print("Configured servers:")
for server in config['servers']:
    print(f"  {server['tag']}:")
    print(f"    Host: {server['host']}")
    print(f"    User: {server['user']}")
    print(f"    Path: {server['path']}")
END


pretty_print "Installation Complete!" ">>" "$GREEN"
echo "
You can now use dropship in these ways:

1. With default server:
   dropship /path/to/file

2. With specific server:
   dropship -d server-tag /path/to/file

3. Add new server configuration:
   dropship -n

4. Show help and list servers:
   dropship -h

Your configuration is saved in ~/.dropship.json

Features:
- Multiple server support
- Progress indicators
- Directory and file transfers
- Secure key-based authentication

Happy shipping!
"
