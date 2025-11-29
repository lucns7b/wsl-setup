#!/bin/bash
set -euo pipefail
# Mock asdf
asdf() {
  if [ "$1" == "plugin-add" ]; then
    if [ "$2" == "existing" ]; then
      return 2 # Simulating exit code 2 for existing plugin
    fi
    return 0
  fi
}

echo "Testing plugin-add..."
asdf plugin-add existing || true
echo "Passed."
