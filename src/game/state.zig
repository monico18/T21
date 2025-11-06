const std = @import("std");
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
};
