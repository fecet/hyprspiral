#!/bin/bash
# Local development wrapper - adds git URL redirection
# Then delegates to build.sh
#
# This script is for local development only. It redirects git URLs
# to local paths, allowing you to test PKGBUILD changes without
# pushing to remote repositories.
#
# For CI builds, use build.sh directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configure git URL redirection via environment variables
# Uses GIT_CONFIG_COUNT/KEY/VALUE to inject config without modifying global files
configure_git_redirect() {
    local count=0

    # Allow all directories to be safe
    export GIT_CONFIG_KEY_${count}="safe.directory"
    export GIT_CONFIG_VALUE_${count}="*"
    count=$((count + 1))

    # Redirect hyprspiral repo to local path
    export GIT_CONFIG_KEY_${count}="url.file://${SCRIPT_DIR}.insteadOf"
    export GIT_CONFIG_VALUE_${count}="https://github.com/fecet/hyprspiral"
    count=$((count + 1))

    # Redirect Hyprland repo if local copy exists
    local hyprland_local="${SCRIPT_DIR}/pkgbuilds/hyprland-spiral/Hyprland"
    if [[ -d "$hyprland_local" ]]; then
        export GIT_CONFIG_KEY_${count}="url.file://${hyprland_local}.insteadOf"
        export GIT_CONFIG_VALUE_${count}="https://github.com/lxe/Hyprland"
        echo "[local_build] Redirecting Hyprland to local: $hyprland_local"
        count=$((count + 1))
    fi

    export GIT_CONFIG_COUNT=$count
}

echo "[local_build] Configuring git URL redirection for local development..."
configure_git_redirect
exec "${SCRIPT_DIR}/build.sh" "$@"
