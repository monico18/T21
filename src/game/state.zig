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

        // immediate blackjack checks
        const outcome = rules.determineOutcome(self.player, self.dealer);
        switch (outcome) {
            .player_blackjack, .dealer_blackjack => {
                self.last_outcome = outcome;
                rules.applyPayout(&self.player, outcome);
                self.phase = .results;
                return;
            },
            else => {},
        }

        self.phase = .player_turn;
    }

    // ───────────────────────────────────────────────
    // Player Actions
    // ───────────────────────────────────────────────

    pub fn playerHit(self: *GameState) void {
        if (self.phase != .player_turn) return;

        self.player.hit(self.deck.deal());

        if (self.player.isBust()) {
            self.finishRound();
            return;
        }
    }

    pub fn playerStand(self: *GameState) void {
        if (self.phase != .player_turn) return;

        self.phase = .dealer_turn;
        self.dealerPlay();
    }

    pub fn playerDouble(self: *GameState) void {
        if (self.phase != .player_turn) return;

        // must double only if player can afford it
        if (!self.player.canBet(self.player.bet)) return;

        // deduct additional bet
        self.player.bankroll -= self.player.bet;
        self.player.bet *= 2;

        // exactly one card
        self.player.hit(self.deck.deal());

        if (!self.player.isBust()) {
            self.phase = .dealer_turn;
            self.dealerPlay();
        } else {
            self.finishRound();
        }
    }

    // ───────────────────────────────────────────────
    // Dealer Phase
    // ───────────────────────────────────────────────

    fn dealerPlay(self: *GameState) void {
        while (rules.dealerShouldHit(self.dealer.hand)) {
            self.dealer.hit(self.deck.deal());
        }
        self.finishRound();
    }

    // ───────────────────────────────────────────────
    // Results Phase
    // ───────────────────────────────────────────────

    fn finishRound(self: *GameState) void {
        const outcome = rules.determineOutcome(self.player, self.dealer);
        self.last_outcome = outcome;
        rules.applyPayout(&self.player, outcome);
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
