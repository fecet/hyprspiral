default:
    @just --list

project_root := justfile_directory()
plugin_default := (project_root / "hyprscroller.so")
pkgbuilds_dir := (project_root / "pkgbuilds")

# Default parallelism for builds (Linux-friendly fallbacks)

jobs := `nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4`

scroller-build j=jobs:
    #!/usr/bin/env bash
    set -euxo pipefail
    make release -j{{ j }}

scroller-reload plugin=plugin_default:
    #!/usr/bin/env bash
    set -euxo pipefail
    echo "[scroller-reload] plugin: {{ plugin }}"
    if ! command -v hyprctl >/dev/null 2>&1; then
      echo "[scroller-reload] error: hyprctl not found in PATH" >&2
      exit 127
    fi
    hyprctl keyword general:layout dwindle || true
    # Try unloading by name first, then by path; ignore if not loaded
    hyprctl plugin unload hyprscroller && hyprctl plugin unload /usr/lib/hyprscroller.so && hyprctl plugin unload '{{ plugin }}' || true
    # Ensure plugin file exists
    if [ ! -e '{{ plugin }}' ]; then
      echo "[scroller-reload] error: plugin not found at {{ plugin }}" >&2
      echo "Build it first: make -C hyprscroller release" >&2
      exit 2
    fi
    hyprctl plugin load '{{ plugin }}'
    hyprctl keyword general:layout scroller
    echo "[scroller-reload] done"

# Package build targets
# Internal function to build a package with makepkg
[private]
_build_pkg dir:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ pkgbuilds_dir }}/{{ dir }}"
    makepkg -seif --noconfirm

# Internal function to install a package with yay (auto-resolves deps)
[private]
_install_pkg dir:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ pkgbuilds_dir }}/{{ dir }}"
    makepkg -si --noconfirm


# Build hyprland-spiral package
pkg-hyprland-spiral:
    @just _build_pkg hyprland-spiral

# Build and install hyprland-spiral package
pkg-hyprland-spiral-install:
    @just _install_pkg hyprland-spiral

# Build hyprland-plugin-spiral package
pkg-hyprland-plugin-spiral:
    @just _build_pkg hyprland-plugin-spiral

# Build and install hyprland-plugin-spiral package
pkg-hyprland-plugin-spiral-install:
    @just _install_pkg hyprland-plugin-spiral

# Build hyprland-plugin-split-monitor-workspaces package
pkg-hyprland-plugin-split-monitor-workspaces:
    @just _build_pkg split-monitor-workspaces

# Build and install hyprland-plugin-split-monitor-workspaces package
pkg-hyprland-plugin-split-monitor-workspaces-install:
    @just _install_pkg split-monitor-workspaces

# Build xdg-desktop-portal-hyprland package
pkg-xdg-desktop-portal-hyprland:
    @just _build_pkg xdg-desktop-portal-hyprland

# Build and install xdg-desktop-portal-hyprland package
pkg-xdg-desktop-portal-hyprland-install:
    @just _install_pkg xdg-desktop-portal-hyprland

# Build all packages in dependency order
pkg-build-all:
    @echo "Building all packages in dependency order..."
    @just pkg-hyprland-spiral-install
    @just pkg-hyprland-plugin-spiral
    @just pkg-hyprland-plugin-split-monitor-workspaces

# Clean all package build artifacts
pkg-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Cleaning package build artifacts..."
    find "{{ pkgbuilds_dir }}" -name "*.pkg.tar.*" -delete
    find "{{ pkgbuilds_dir }}" -name "*.src.tar.*" -delete
    find "{{ pkgbuilds_dir }}" -type d -name "src" -exec rm -rf {} + 2>/dev/null || true
    find "{{ pkgbuilds_dir }}" -type d -name "pkg" -exec rm -rf {} + 2>/dev/null || true
    find "{{ pkgbuilds_dir }}" -type d -name "Hyprland" -exec rm -rf {} + 2>/dev/null || true
    echo "Clean complete."
