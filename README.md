# 🚀 Dropship

A simple yet powerful file transfer utility that makes it easy to send files and directories to your remote servers. Built on top of rsync with a focus on user experience and visual feedback.

## Features

- 📦 Simple, intuitive command-line interface
- 🔑 Secure transfers using SSH
- 🎯 Multiple server support with easy switching
- 📊 Real-time transfer progress with spinner
- 🔄 Smart conflict resolution
- 🚦 Transfer speed and ETA display
- 🎨 Colorful, easy-to-read output

## Installation

```bash
# Clone the repository
git clone https://github.com/matdotcx/dropship.git

# Make it executable
chmod +x install_drop.sh

# Run the installation script
./install_drop.sh
```

The installation script will:
1. Create necessary directories
2. Set up SSH keys if needed
3. Configure your first remote server
4. Install the `dropship` command

## Usage

### Basic Usage

Send a file or directory to your default server:
```bash
dropship path/to/file
```

### Specify a Different Server

Send to a specific server using its tag:
```bash
dropship -d server-tag path/to/file
```

### Add New Server Configuration

Add a new server to your configuration:
```bash
dropship -n
```

### List Available Servers

Show help and list configured servers:
```bash
dropship -h
```

## Configuration

Dropship stores its configuration in `~/.dropship.json`. Each server entry includes:
- Tag (unique identifier)
- Username
- Hostname
- Destination path

Example configuration:
```json
{
  "default": "webhost",
  "servers": [
    {
      "tag": "webhost",
      "user": "username",
      "host": "example.com",
      "path": "/home/username"
    }
  ]
}
```

## Features in Detail

### Smart Conflict Resolution

When a file or directory already exists at the destination, Dropship offers three options:
- Update existing files
- Create a new copy with an incremented name
- Cancel the transfer

### Progress Display

The progress indicator shows:
- Spinning activity indicator
- Transfer percentage
- Current file name
- Transfer speed
- Estimated time remaining

Example:
```
⠋ 45% folder1/largefile1.bin (52.64MB/s, 0:00:15)
```

### Security

- Uses SSH for secure transfers
- Supports ED25519 key authentication
- No plaintext passwords stored

## Requirements

- macOS or Linux
- Bash 4.0+
- rsync
- SSH client
- Python 3.x (for JSON configuration handling)

## Acknowledgments

Built with:
- rsync for reliable file transfers
- SSH for secure communication
- Python for JSON configuration handling
- Bash for the command-line interface
