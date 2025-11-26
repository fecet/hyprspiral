#!/bin/bash
# Core build script for hyprspiral packages
# Used by both local development (via local_build.sh) and CI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILDS_DIR="${SCRIPT_DIR}/pkgbuilds"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"

# Build a single package
build_package() {
    local pkgbuild_dir="$1"
    local pkg_name=$(basename "$pkgbuild_dir")
    local build_dir="${pkgbuild_dir}/build_tmp"

    print_info "Building: $pkg_name"

    # Clean up old packages
    rm -f "${pkgbuild_dir}"/*.pkg.tar.zst

    # Create build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    # Copy PKGBUILD and patches
    cp "${pkgbuild_dir}/PKGBUILD" "$build_dir/"
    if compgen -G "${pkgbuild_dir}/*.patch" > /dev/null; then
        cp "${pkgbuild_dir}"/*.patch "$build_dir/" 2>/dev/null || true
    fi

    # Build
    (
        cd "$build_dir"
        # -s: install dependencies (syncdeps)
        # -f: force rebuild
        # --noconfirm: don't ask for confirmation
        makepkg -sf --noconfirm
    )

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        # Move built packages to parent directory
        mv "$build_dir"/*.pkg.tar.zst "$pkgbuild_dir/" 2>/dev/null || true
        print_info "Built: $pkg_name"
    else
        print_error "Failed to build: $pkg_name"
        return $exit_code
    fi
}

# Install all packages from a build directory
install_package() {
    local pkgbuild_dir="$1"
    local pkg_files=()

    while IFS= read -r -d '' file; do
        pkg_files+=("$file")
    done < <(find "$pkgbuild_dir" -maxdepth 1 -name "*.pkg.tar.zst" -type f -print0)

    if [[ ${#pkg_files[@]} -eq 0 ]]; then
        print_error "No package found in $pkgbuild_dir"
        return 1
    fi

    for pkg_file in "${pkg_files[@]}"; do
        print_info "Installing: $(basename "$pkg_file")"
    done

    $SUDO pacman -U --noconfirm "${pkg_files[@]}"
}

# Cleanup temporary files
cleanup() {
    local pkgbuild_dir="$1"
    print_info "Cleaning up: $(basename "$pkgbuild_dir")"
    rm -rf "${pkgbuild_dir}/build_tmp"
}

# Main build logic: two-phase build
main() {
    print_info "Hyprspiral Build Script"
    print_info "PKGBUILDS_DIR: $PKGBUILDS_DIR"
    echo

    # Phase 1: Build and install hyprland-spiral (other packages depend on it)
    local spiral_dir="${PKGBUILDS_DIR}/hyprland-spiral"
    if [[ -d "$spiral_dir" ]] && [[ -f "$spiral_dir/PKGBUILD" ]]; then
        print_info "=== Phase 1: Building hyprland-spiral ==="

        if build_package "$spiral_dir"; then
            if [[ "$INSTALL_PKG" == "1" ]]; then
                install_package "$spiral_dir"
            fi
        else
            print_error "Phase 1 failed"
            exit 1
        fi

        [[ "$KEEP_TEMP" != "1" ]] && cleanup "$spiral_dir"

        # Remove hyprland-protocols after Phase 1 to avoid conflict with xdg-desktop-portal-hyprland
        if pacman -Q hyprland-protocols &>/dev/null; then
            print_info "Removing hyprland-protocols (makedepend only, conflicts with xdg-desktop-portal-hyprland)"
            $SUDO pacman -Rdd --noconfirm hyprland-protocols
        fi
        echo
    fi

    # Phase 2: Build other packages
    print_info "=== Phase 2: Building other packages ==="
    for pkgdir in "$PKGBUILDS_DIR"/*; do
        [[ "$(basename "$pkgdir")" == "hyprland-spiral" ]] && continue
        [[ -f "$pkgdir/PKGBUILD" ]] || continue

        if build_package "$pkgdir"; then
            [[ "$INSTALL_PKG" == "1" ]] && install_package "$pkgdir"
        else
            print_error "Failed to build: $(basename "$pkgdir")"
            # Continue with other packages
        fi

        [[ "$KEEP_TEMP" != "1" ]] && cleanup "$pkgdir"
        echo
    done

    print_info "Build completed"
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
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Build all packages in pkgbuilds/ directory"
            echo
            echo "Options:"
            echo "  --install, -i  Install packages after building"
            echo "  --keep-temp    Keep temporary build files"
            echo "  --help, -h     Show this help message"
            echo
            echo "For local development with git URL redirection, use local_build.sh instead"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

main "$@"
