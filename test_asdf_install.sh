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
for plugin in nodejs java python tmux micro uv pipx lazydocker; do
    if ! asdf plugin-list | grep -q "$plugin"; then
        echo "asdf $plugin plugin not found"
        exit 1
    fi
done

# Check if the tools are available
# Note: some tools might not be in the path if shim rehash didn't happen or shell didn't reload,
# but sourcing asdf.sh should handle it.
for tool in node java python tmux micro uv pipx lazydocker; do
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool could not be found via asdf"
        # Try to reshim just in case
        asdf reshim "$tool"
        if ! command -v "$tool" &> /dev/null; then
             echo "Still cannot find $tool"
             exit 1
        fi
    fi
done

echo "asdf and all plugins and tools installed successfully"
exit 0
