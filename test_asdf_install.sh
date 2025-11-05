#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Determine the target user and home directory
TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(whoami)}}"
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"

# Run the setup script
sudo ./setup.sh

# Source asdf from the correct home directory
# shellcheck source=/dev/null
. "$TARGET_HOME/.asdf/asdf.sh"

# Check if asdf is installed
if ! command -v asdf &> /dev/null; then
    echo "asdf could not be found"
    exit 1
fi

# Check if the plugins are installed
for plugin in nodejs java python; do
    if ! asdf plugin-list | grep -q "$plugin"; then
        echo "asdf $plugin plugin not found"
        exit 1
    fi
done

# Check if the tools are available
for tool in node java python uv pipx; do
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool could not be found"
        exit 1
    fi
done

echo "asdf and all plugins and tools installed successfully"
exit 0
