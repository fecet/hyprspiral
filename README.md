# Spiral Layout for Hyprland

This monorepo refines both Hyprland and the hyprscroller layout plugin to introduce a new automatic placement mode: `spiral`.

## Why Spiral
- Center-first cognition: windows grow from screen center outward, forming a Manhattan/chebyshev “square spiral” that matches users’ mental model.
- Stable indexing: the insertion order follows a deterministic spiral sequence, aiding spatial memory and muscle memory.
- Local changes: opening/closing windows primarily affects nearby slots, minimizing layout churn.
- Robust to size/resolution: the directionality and ordering stay consistent across monitor changes.

Spiral is an additional auto-placement strategy beside existing `manual` and `auto`. It requires no `N` parameter; the layout expands as needed.

## Mental Model
Let r be the Chebyshev radius from the center (r = 0, 1, 2, …). For each ring r, we traverse positions in clockwise order. The step lengths follow 1, 1, 2, 2, 3, 3, … with direction repeating →, ↓, ←, ↑ for a horizontal-first (Row) perspective; rotate this mapping by 90° for a vertical-first (Column) perspective.

Examples

Row (landscape):

```
789
612
543
```

Column (portrait):

```
765
814
923
```

## Mode/Position Mapping
Spiral relies solely on flipping the scroller working `mode` and its `ModeModifier::position` to realize the clockwise sequence—no global state machine is introduced.

- Row mapping
  - Extend right (new column to the right) → `mode = Row`, `position = end`.
  - Fill down (append within the column) → `mode = Column`, `position = end`.
  - Extend left (new column to the left) → `mode = Row`, `position = beginning`.
  - Fill up (insert at top of the column) → `mode = Column`, `position = beginning`.

- Column mapping (rotate the above by 90°)
  - Add rows with `mode = Column`; append within a row using `mode = Row`.
  - Choose `position = beginning/end` analogously (top/bottom vs. left/right).

When the next spiral step falls on a non-active column, `find_auto_insert_point` returns a `new_active` pointer to that target column; everything else remains local.

## How It Works
All spiral logic lives in `find_auto_insert_point`, which decides three things per insertion: `mode`, `position`, and `new_active`. The algorithm intentionally keeps no extra metadata and is resilient to user interventions like `expel` or removing middle windows—new windows are guided back onto the spiral track.

High-level procedure

1) Sample the current state
   - Walk existing columns; collect nodes and total window count. If empty, set `mode = Row`, `position = after` to create the first column.

2) Rebuild the theoretical sequence
   - Generate spiral coordinates for indices 1…N+1.
   - Determine current `min_x`/`max_x`, and map each `(x, y)` to a column index by linear normalization with rounding, so center alignment remains stable under changing column counts.

3) Find the first gap
   - “Account” for real windows against the spiral order. The first index that cannot be matched marks `missing_index`; otherwise the target is `total_windows + 1`.

4) Decide the operation
   - If the target column lies beyond current bounds, switch to `mode = Row` and set `position = beginning/end` to grow left/right.
   - Otherwise switch to `mode = Column`, set `new_active` to the mapped column, and choose `position = beginning/after/end` based on `y` relative to that column’s expected range.

5) No external state
   - Only `mode`, `position`, `new_active` are produced. `add_active_window` saves/restores these, so temporary changes do not leak into manual operations.

## Install from GitHub Releases (Arch-based)

This project ships binary packages as a pacman repo hosted on GitHub Releases.

Supported: Arch Linux and derivatives (pacman ≥ 6). Packages are currently built for `x86_64`.

1) Add the repo to pacman

Edit `/etc/pacman.conf` and append:

```
[hyprspiral]
SigLevel = Optional
Server = https://github.com/fecet/hyprspiral/releases/latest/download
```

Alternatively, drop the above section into a separate file like `/etc/pacman.d/hyprspiral.repo` and include it from `pacman.conf` with:

```
Include = /etc/pacman.d/hyprspiral.repo
```

2) Refresh databases

```
sudo pacman -Syy
```

3) Install packages

Hyprland (spiral-enabled fork; conflicts with the upstream `hyprland` package):

```
sudo pacman -S hyprspiral/hyprland-spiral
```

Core plugin and extras:

```
sudo pacman -S \
  hyprspiral/hyprland-plugin-spiral \
  hyprspiral/hyprland-plugin-split-monitor-workspaces \
  hyprspiral/xdg-desktop-portal-hyprland-input-capture
```

Notes

- Replacing upstream Hyprland: because `hyprland-spiral` `conflicts=('hyprland')` and `provides=('hyprland=…')`, pacman may prompt to remove `hyprland`. Confirm to switch to the spiral build.
- Listing available packages: `pacman -Sl hyprspiral`.
- Updating: keep the repo entry as-is and run `sudo pacman -Syu` to track the "Latest" release. To pin a specific release, replace `latest` in the `Server` URL with a concrete tag name once tags beyond `latest` are published.
