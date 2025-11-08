T21 — Terminal Blackjack
=====================================

T21 is a small terminal-based Blackjack (21) game written in Zig.
It supports standard Blackjack gameplay and includes a split feature
(you can split a pair into two hands). The UI uses the vaxis/vxfw
terminal UI framework.

Features
--------
- Single-player Blackjack vs dealer.
- Place bets and track bankroll.
- Split a pair into two hands with per-hand bets and payouts.
- Keyboard controls and TUI buttons.
- Results screen shows per-hand outcomes for splits.

Requirements
------------
- Zig (compile & run using the project's Zig build configuration).
- A Unix-like terminal (Linux/macOS). Development was done on Linux.

Build
-----
From the repository root:

```bash
# Build in debug mode (default)
zig build
```

Install
-------
Several release artifacts are published on GitHub Releases (example names):

- `T21-linux-<version>.deb`
- `T21-macos-<version>.dmg`
- `T21-archlinux-<version>.tar.gz` (contains `PKGBUILD`, README, LICENSE)

Install from source
-------------------
Build from the repo and run the binary directly:

```fish
# build (from project root)
zig build

# run the built binary
./zig-out/bin/T21
```

Install from Arch/PKGBUILD
--------------------------
Download the `T21-archlinux-<version>.tar.gz` from the Releases page, extract it and build with `makepkg`:

```bash
tar xzf T21-archlinux-<version>.tar.gz
cd T21-archlinux-<version>
# builds and installs the package (requires base-devel)
makepkg -si
```

Install from .deb (Debian/Ubuntu)
---------------------------------
Download `T21-linux-<version>.deb` from Releases and install with `apt` or `dpkg`:

```bash
# recommended (resolves deps):
sudo apt install ./T21-linux-<version>.deb

# or using dpkg directly:
sudo dpkg -i T21-linux-<version>.deb
sudo apt-get install -f    # fix missing dependencies, if any
```

Install from .dmg (macOS)
-------------------------
Download `T21-macos-<version>.dmg`, mount it and copy the T21 binary or app bundle to `/Applications` or run it in-place:

```bash
# mount the dmg (macOS)
hdiutil attach T21-macos-<version>.dmg

# after mounting, copy the app or binary from the mounted volume to /Applications
cp -R /Volumes/T21/T21.app /Applications/

# eject when done
hdiutil detach /Volumes/T21
```

Where to get packages
----------------------
Built packages and release archives are attached to the project's GitHub Releases for each release tag. Look for artifacts named `T21-*-<version>*` on the Releases page.


Controls
--------
- Use the arrow keys or the on-screen buttons to select actions.
- Keyboard shortcuts (when in a player's turn):
  - h — Hit
  - s — Stand
  - d — Double
  - t — Split
  - 1 / 2 — Quick-select active hand when split
  - q or Ctrl+C — Quit
- When betting: use the betting screen UI to increase/decrease and place bets.

Files of interest
-----------------
- `src/game/` — game model: `hand.zig`, `player.zig`, `state.zig`, `rules.zig`, `deck.zig`, `card.zig`.
- `src/ui/` — UI screens and widgets (`table.zig`, `results.zig`, widgets/...).
- `LICENSE` — GNU General Public License v2 applied to the repository.

Testing
-------
There are a few unit tests for game logic in `src/game` (if present). Run them with:

```fish
zig test src/game
```

Notes about split behavior
-------------------------
- When you split a pair the bet from hand 0 is duplicated to hand 1 and the same amount is deducted from the bankroll.
- Each split hand is evaluated separately against the dealer and payouts applied per-hand.
- The results screen shows per-hand outcomes ("You win", "You lose", "Push", etc.).

License
-------
This project is licensed under the GNU General Public License v2 (GPLv2).
See the `LICENSE` file in the project root for the full text.

TODO
----
- [ ] Add unit tests that assert per-hand outcomes for split scenarios (happy/edge cases).
- [ ] Implement split-ace special rules (only one card dealt to each ace split by default).
- [ ] Add color styling to the results screen (green for wins, red for losses).
- [ ] Polish UI layout and accessibility (focus handling, on-screen help text).

Contributing
------------
Contributions welcome. Please open issues or pull requests. By
contributing you agree to license your contribution under the project's
GPLv2 license.

