#!/bin/bash
# Script to build PKGBUILDs locally using local git paths instead of remote URLs
# This allows testing package builds without fetching from remote repositories

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the absolute path to the hyprspiral repository root
HYPRSPIRAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILDS_DIR="${HYPRSPIRAL_ROOT}/pkgbuilds"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to configure git environment variables for URL redirection
# This uses GIT_CONFIG_COUNT/KEY/VALUE to inject config into git processes
# without modifying global or system config files.
configure_git_env() {
    print_info "Configuring git environment variables for URL redirection..."
    
    local count=0
    
    # Redirect hyprspiral repo
    export GIT_CONFIG_KEY_${count}="url.${HYPRSPIRAL_ROOT}.insteadOf"
    export GIT_CONFIG_VALUE_${count}="https://github.com/fecet/hyprspiral"
    count=$((count + 1))
    
    # Redirect Hyprland repo if local copy exists
    local hyprland_local="${HYPRSPIRAL_ROOT}/pkgbuilds/hyprland-spiral/Hyprland"
    if [[ -d "$hyprland_local" ]]; then
        export GIT_CONFIG_KEY_${count}="url.${hyprland_local}.insteadOf"
        export GIT_CONFIG_VALUE_${count}="https://github.com/lxe/Hyprland"
        print_info "Redirecting Hyprland to local: $hyprland_local"
        count=$((count + 1))
    fi
    
    export GIT_CONFIG_COUNT=$count
}

# Function to build a package using the local PKGBUILD
build_package() {
    local pkgbuild_dir="$1"
    
    print_info "Building package: $(basename "$pkgbuild_dir")"
    
    # Create a temporary build directory
    local build_dir="${pkgbuild_dir}/build_tmp"
    mkdir -p "$build_dir"
    
    # Copy the PKGBUILD to the build directory
    # We don't need to modify it anymore because git config handles the redirection
    cp "${pkgbuild_dir}/PKGBUILD" "${build_dir}/PKGBUILD"
    
    # Copy any patch files if they exist
    if compgen -G "${pkgbuild_dir}/*.patch" > /dev/null; then
        cp "${pkgbuild_dir}"/*.patch "$build_dir/" 2>/dev/null || true
    fi
    
    # Change to build directory and run makepkg
    (
        cd "$build_dir"
        print_info "Running makepkg in: $build_dir"
        makepkg -sf --noconfirm
    )
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        print_info "Successfully built: $(basename "$pkgbuild_dir")"
        # Move built packages to the parent directory
        mv "$build_dir"/*.pkg.tar.zst "$pkgbuild_dir/" 2>/dev/null || true
    else
        print_error "Failed to build: $(basename "$pkgbuild_dir")"
    fi
    
    return $exit_code
}

# Function to install the built package
install_package() {
    local pkgbuild_dir="$1"
    
    print_info "Installing package from: $(basename "$pkgbuild_dir")"
    
    # Find the built package
    local pkg_file=$(find "$pkgbuild_dir" -maxdepth 1 -name "*.pkg.tar.zst" | head -n 1)
    
    if [[ -z "$pkg_file" ]]; then
        print_error "No package file found in $pkgbuild_dir"
        return 1
    fi
    
    print_info "Installing $pkg_file..."
    if $SUDO pacman -U --noconfirm "$pkg_file"; then
        print_info "Successfully installed: $(basename "$pkgbuild_dir")"
        return 0
    else
        print_error "Failed to install: $(basename "$pkgbuild_dir")"
        return 1
    fi
}

# Function to clean up temporary files
cleanup() {
    local pkgbuild_dir="$1"
    
    print_info "Cleaning up temporary files for $(basename "$pkgbuild_dir")"
    
    rm -rf "${pkgbuild_dir}/build_tmp"
}

# Main script
main() {
    print_info "Hyprspiral Local Build Script"
    print_info "Repository root: $HYPRSPIRAL_ROOT"
    echo
    
    # Configure git environment variables
    configure_git_env
    
    # Check if a specific package is requested
    if [[ $# -gt 0 ]]; then
        # Build specific packages
        for pkg in "$@"; do
            local pkgdir="${PKGBUILDS_DIR}/${pkg}"
            if [[ ! -d "$pkgdir" ]]; then
                print_error "Package directory not found: $pkg"
                continue
            fi
            
            print_info "Processing package: $pkg"
            
            if build_package "$pkgdir"; then
                if [[ "$INSTALL_PKG" == "1" ]]; then
                    install_package "$pkgdir"
                fi
            fi
            
            if [[ "$KEEP_TEMP" != "1" ]]; then
                cleanup "$pkgdir"
            fi
            echo
        done
    else
        # Build all packages
        print_info "Building all packages in: $PKGBUILDS_DIR"
        echo
        
        for pkgdir in "$PKGBUILDS_DIR"/*; do
            if [[ ! -d "$pkgdir" ]] || [[ ! -f "$pkgdir/PKGBUILD" ]]; then
                continue
            fi
            
            local pkgname=$(basename "$pkgdir")
            print_info "Processing package: $pkgname"
            
            if build_package "$pkgdir"; then
                if [[ "$INSTALL_PKG" == "1" ]]; then
                    install_package "$pkgdir"
                fi
            fi
            
            if [[ "$KEEP_TEMP" != "1" ]]; then
                cleanup "$pkgdir"
            fi
            echo
        done
    fi
    
    print_info "Build process completed"
}

# Parse command line arguments
KEEP_TEMP=0
INSTALL_PKG=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-temp)
            KEEP_TEMP=1
            shift
            ;;
        --install|-i)
            INSTALL_PKG=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [PACKAGE_NAMES...]"
            echo
            echo "Build PKGBUILDs locally using local git paths"
            echo
            echo "Options:"
            echo "  --keep-temp    Keep temporary files after build"
            echo "  --install, -i  Install the package after building (requires sudo if not root)"
            echo "  --help, -h     Show this help message"
            echo
            echo "Examples:"
            echo "  $0                           # Build all packages"
            echo "  $0 hyprland-plugin-spiral    # Build specific package"
            echo "  $0 hyprland-spiral wl-kbptr  # Build multiple packages"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

main "$@"
