# Repository Guidelines

## Project Structure & Module Organization
- `src/` — C++23 sources for the Hyprland layout plugin (`hyprscroller`).
- `CMakeLists.txt` — build targets and dependencies (pkg-config: `hyprland`, `hyprutils`, `hyprlang`, `pixman-1`, `libdrm`, `pangocairo`).
- `Makefile` — convenience targets for local builds (`debug`, `release`, `install`).
- `pkgbuilds/` — Arch packaging recipes.
- `hypr.conf` — example configuration; adjust to enable the `scroller` layout.
- `README.md`, `TUTORIAL.md` — user docs and feature overview.

## Build, Test, and Development Commands
- `make debug` — configure and build Debug, symlink `compile_commands.json` and `hyprscroller.so` to repo root.
- `make release` — configure and build Release, same symlinks.
- `make install` — copy `hyprscroller.so` to `$(xdg-user-dir)/.config/hypr/plugins`.
- CMake (manual): `cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j`.
- Run locally: install the `.so`, then switch Hyprland to the `scroller` layout (see README/TUTORIAL).

## Coding Style & Naming Conventions
- Language: C++23; indent 4 spaces; UTF-8; keep diffs minimal.
- Types/Enums: `PascalCase` (e.g., `ScrollerLayout`, `Direction`).
- Functions/Methods/Variables: `snake_case` (e.g., `cycle_window_size`, `new_active`).
- Constants/macros: `UPPER_CASE`; header guards as in existing files (e.g., `SCROLLER_SCROLLER_H`).
- Includes: standard → third‑party → local; prefer precise headers.
- Comments: only for key logic and invariants; use English.

## Testing Guidelines
- No formal test suite yet. Verify: builds clean in Debug/Release; plugin loads; core flows (create/move/expel, overview, gestures) behave as documented.
- For new modules, add minimal self-checks or assertions where helpful; consider proposing a gtest harness in a separate PR.

## Commit & Pull Request Guidelines
- Use Conventional Commits (English): `feat:`, `fix:`, `perf:`, `refactor:`, `docs:`, `chore:`, `build:`.
- Commits: focused, logically grouped, with clear rationale and scope.
- PRs: include summary, rationale, user-visible changes, config snippets if needed, and links to issues. Update README/TUTORIAL on behavior changes. Add before/after screenshots where UI-visible.

## Agent-Specific Notes
- This file governs the whole repo. Keep patches surgical: avoid unrelated refactors/renames. Preserve existing style and public APIs. When touching `src/`, prefer local fixes and small, reviewable diffs.

