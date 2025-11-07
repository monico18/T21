const std = @import("std");
// no C imports: prefer a simple local save dir under the current working directory
const Deck = @import("deck.zig").Deck;
const Player = @import("player.zig").Player;
const rules = @import("rules.zig");

pub const Phase = enum {
    betting,
    dealing,
    player_turn,
    dealer_turn,
    results,
};

pub const GameState = struct {
    allocator: std.mem.Allocator,
    deck: Deck,
    player: Player,
    dealer: Player,

    phase: Phase = .betting,
    last_outcome: ?rules.RoundOutcome = null,
    // Per-hand outcomes for the last round (useful when player split)
    last_outcomes: [2]rules.RoundOutcome = .{ .push, .push },
    // Snapshot of the player's bets and hand count for display on the
    // results screen. We record these before applying payouts which
    // zero the player's bets.
    last_bets: [2]i32 = .{ 0, 0 },
    last_hand_count: usize = 1,

    pub fn init(
        allocator: std.mem.Allocator,
        num_decks: usize,
        starting_money: i32,
    ) !GameState {
        var deck = try Deck.init(allocator, num_decks);
        deck.shuffle();

        return .{
            .allocator = allocator,
            .deck = deck,
            .player = Player.init("Player", starting_money, false),
            .dealer = Player.init("Dealer", 0, true),
            .phase = .betting,
            .last_outcome = null,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit(self.allocator);
        // players don't allocate anything dynamically except strings passed in externally
    }

    // ───────────────────────────────────────────────
    // Betting Phase
    // ───────────────────────────────────────────────

    pub fn placeBet(self: *GameState, amount: i32) bool {
        if (self.player.placeBet(amount)) {
            self.phase = .dealing;
            return true;
        }
        return false;
    }

    // ───────────────────────────────────────────────
    // Dealing Phase
    // ───────────────────────────────────────────────

    pub fn beginRound(self: *GameState) void {
        // Reset only the hands here — do not clear the player's bet, which
        // was placed during the betting phase and must persist for the round.
        self.player.resetHand();
        self.dealer.resetHand();

        // player 2 cards
        self.player.hit(self.deck.deal());
        self.player.hit(self.deck.deal());

        // dealer 2 cards
        self.dealer.hit(self.deck.deal());
        self.dealer.hit(self.deck.deal());

        // immediate blackjack checks (single-hand case)
        const p_bj = self.player.isBlackjackHand(0);
        const d_bj = self.dealer.isBlackjackHand(0);
        if (p_bj or d_bj) {
            if (p_bj and d_bj) {
                self.last_outcome = rules.RoundOutcome.push;
            } else if (p_bj) {
                self.last_outcome = rules.RoundOutcome.player_blackjack;
            } else {
                self.last_outcome = rules.RoundOutcome.dealer_blackjack;
            }
            // apply payout(s) as appropriate for hand 0
            rules.applyPayoutFor(&self.player, 0, self.last_outcome.?);
            self.phase = .results;
            return;
        }

        self.phase = .player_turn;
    }

    // ───────────────────────────────────────────────
    // Player Actions
    // ───────────────────────────────────────────────

    pub fn playerHit(self: *GameState) void {
        if (self.phase != .player_turn) return;

        self.player.hit(self.deck.deal());

        // If current hand busts, either move to next hand or finish
        if (self.player.isBustHand(self.player.active_hand)) {
            // mark bust and move to next hand if available
            if (self.player.hand_count > 1 and self.player.active_hand == 0) {
                // move to second hand
                self.player.active_hand = 1;
            } else {
                self.finishRound();
                return;
            }
        }
    }

    pub fn playerStand(self: *GameState) void {
        if (self.phase != .player_turn) return;

        // If there is a second hand and we're on the first, switch to it
        if (self.player.hand_count > 1 and self.player.active_hand == 0) {
            self.player.active_hand = 1;
            return;
        }

        self.phase = .dealer_turn;
        self.dealerPlay();
    }

    pub fn playerDouble(self: *GameState) void {
        if (self.phase != .player_turn) return;
        // must double only if player can afford the additional bet for the current hand
        const idx = self.player.active_hand;
        const curr_bet = self.player.bets[idx];
        if (curr_bet <= 0 or curr_bet > self.player.bankroll) return;

        // deduct additional bet
        self.player.bankroll -= curr_bet;
        self.player.bets[idx] = curr_bet * 2;

        // exactly one card to current hand
        self.player.hit(self.deck.deal());

        if (!self.player.isBustHand(idx)) {
            // if there is a second hand and we just finished first, move to it
            if (self.player.hand_count > 1 and idx == 0) {
                self.player.active_hand = 1;
                return;
            }
            self.phase = .dealer_turn;
            self.dealerPlay();
        } else {
            self.finishRound();
        }
    }

    // Split the player's initial hand into two hands if allowed
    pub fn playerSplit(self: *GameState) void {
        if (self.phase != .player_turn) return;
        // only allow splitting when on first hand and it has exactly 2 cards
        if (self.player.hand_count != 1) return;
        const h = self.player.hands[0];
        if (h.count != 2) return;
        const c0 = h.cards[0];
        const c1 = h.cards[1];
        if (c0.rank != c1.rank) return;

        // must be able to match the bet
        if (!self.player.applySplitBet()) return;

        // move second card to hand 1
        self.player.hands[1].reset();
        self.player.hands[1].addCard(c1);
        // shrink hand 0 to only the first card
        self.player.hands[0].count = 1;
        self.player.hand_count = 2;
        self.player.active_hand = 0;
        // Deal one additional card to each hand as per standard split rules
        self.player.hands[0].addCard(self.deck.deal());
        self.player.hands[1].addCard(self.deck.deal());
    }

    // ───────────────────────────────────────────────
    // Dealer Phase
    // ───────────────────────────────────────────────

    fn dealerPlay(self: *GameState) void {
        while (rules.dealerShouldHit(self.dealer.hands[0])) {
            self.dealer.hands[0].addCard(self.deck.deal());
        }
        self.finishRound();
    }

    // ───────────────────────────────────────────────
    // Results Phase
    // ───────────────────────────────────────────────

    fn finishRound(self: *GameState) void {
        // Snapshot player's bets/hand count for the results screen before
        // applying payouts (which will clear bets).
        self.last_bets[0] = self.player.bets[0];
        self.last_bets[1] = self.player.bets[1];
        self.last_hand_count = self.player.hand_count;

        // Evaluate each player hand vs dealer and apply payouts per-hand
        // First ensure dealer value is final (dealerPlay should have been called)
        var idx: usize = 0;
        while (idx < self.player.hand_count) : (idx += 1) {
            const outcome = rules.determineOutcomeForHands(self.player.hands[idx], self.dealer.hands[0]);
            // store per-hand outcomes for UI
            self.last_outcomes[idx] = outcome;
            // store last_outcome as the last hand's outcome for backward compat
            self.last_outcome = outcome;
            rules.applyPayoutFor(&self.player, idx, outcome);
        }
        self.phase = .results;
    }

    /// Call this after the UI shows the results screen and the player presses Enter
    pub fn resetForNextRound(self: *GameState) void {
        self.last_outcome = null;
        self.phase = .betting;
    }

    // Persist the player's bankroll to a small binary file. The file will
    // contain a 32-bit little-endian signed integer representing the
    // bankroll value.
    pub fn saveBankroll(self: *GameState, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();

        var buf: [4]u8 = undefined;
        const v: u32 = @as(u32, @intCast(self.player.bankroll));

        // Extract bytes explicitly. Use @intCast to make the intermediate
        // expressions compatible with the project's casting idioms.
        buf[0] = @as(u8, @intCast(v & @as(u32, 0xFF)));
        buf[1] = @as(u8, @intCast((v >> 8) & @as(u32, 0xFF)));
        buf[2] = @as(u8, @intCast((v >> 16) & @as(u32, 0xFF)));
        buf[3] = @as(u8, @intCast((v >> 24) & @as(u32, 0xFF)));

        try file.writeAll(buf[0..]);
    }

    // Load bankroll from a binary file previously written by saveBankroll.
    // If the file is missing or malformed an error will be returned.
    pub fn loadBankroll(self: *GameState, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf: [4]u8 = undefined;
        var total: usize = 0;
        while (total < buf.len) {
            const n = try file.read(buf[total..]);
            if (n == 0) {
                const Err = error{FileTooSmall};
                return Err.FileTooSmall;
            }
            total += n;
        }

        const v: u32 = @as(u32, buf[0]) | (@as(u32, buf[1]) << 8) | (@as(u32, buf[2]) << 16) | (@as(u32, buf[3]) << 24);

        self.player.bankroll = @intCast(v);
    }

    /// Save to the user's home config location (~/.t21/bankroll.bin) if
    /// possible, otherwise fall back to the current working directory.
    pub fn saveBankrollDefault(self: *GameState) !void {
        // Attempt to create a local config directory and save there; if that
        // fails, fall back to a simple bankroll.bin in cwd. Use comptime
        // checks to call whichever API is available in this Zig stdlib.
        comptime {
            if (@hasDecl(std.fs.Dir, "createDir")) {
                _ = std.fs.cwd().createDir(".t21", .{}) catch {};
            } else if (@hasDecl(std.os, "mkdir")) {
                _ = std.os.mkdir(".t21", 0o700) catch {};
            } else {
                // no reliable mkdir API available in this stdlib version; skip
            }
        }
        self.saveBankroll(".t21/bankroll.bin") catch {
            try self.saveBankroll("bankroll.bin");
        };
    }

    /// Load from the user's home config location (~/.t21/bankroll.bin) if
    /// possible, otherwise fall back to $HOME/bankroll.bin or ./bankroll.bin.
    pub fn loadBankrollDefault(self: *GameState) !void {
        // Prefer the local .t21 directory under cwd
        const f = std.fs.cwd().openFile(".t21/bankroll.bin", .{}) catch null;
        if (f != null) {
            _ = f.close();
            try self.loadBankroll(".t21/bankroll.bin");
            return;
        }
        // fallback to cwd
        try self.loadBankroll("bankroll.bin");
    }
};
