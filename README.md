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

```fish
# Build in debug mode (default)
zig build
```

Run
---
After building the executable is placed in `zig-out/bin/T21`:

```fish
./zig-out/bin/T21
```

Controls
--------
- Use the arrow keys or the on-screen buttons to select actions.
- Keyboard shortcuts (when in a player's turn):
  - h — Hit
  - s — Stand
  - d — Double
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

