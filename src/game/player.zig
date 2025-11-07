const std = @import("std");
const Hand = @import("hand.zig").Hand;

pub const Player = struct {
    name: []const u8,
    hands: [2]Hand = undefined,
    hand_count: usize = 1,
    active_hand: usize = 0,
    bankroll: i32 = 0,
    bets: [2]i32 = .{ 0, 0 },
    is_dealer: bool = false,

    pub fn init(name: []const u8, starting_bankroll: i32, is_dealer: bool) Player {
        return .{
            .name = name,
            .hands = .{ .{}, .{} },
            .hand_count = 1,
            .active_hand = 0,
            .bankroll = starting_bankroll,
            .bets = .{ 0, 0 },
            .is_dealer = is_dealer,
        };
    }

    // Reset hand and bet for a new round
    // Reset both hands and bets for a new round
    pub fn resetForRound(self: *Player) void {
        self.hands[0].reset();
        self.hands[1].reset();
        self.hand_count = 1;
        self.active_hand = 0;
        self.bets[0] = 0;
        self.bets[1] = 0;
    }

    // Reset only the hand (keep bet intact). Used when starting a round after
    // a bet has already been placed.
    // Reset only hands (keep bets intact when re-dealing)
    pub fn resetHand(self: *Player) void {
        self.hands[0].reset();
        self.hands[1].reset();
        self.hand_count = 1;
        self.active_hand = 0;
    }

    // Add a card to this player's hand
    pub fn hit(self: *Player, card: anytype) void {
        self.hands[self.active_hand].addCard(card);
    }

    // Check hand value
    // Value and status queries for the active hand or a specific hand
    pub fn handValue(self: Player, idx: usize) u8 {
        return self.hands[idx].value();
    }

    pub fn isBustHand(self: Player, idx: usize) bool {
        return self.hands[idx].isBust();
    }

    pub fn isBlackjackHand(self: Player, idx: usize) bool {
        return self.hands[idx].isBlackjack();
    }

    pub fn canBet(self: Player, amount: i32) bool {
        return amount > 0 and amount <= self.bankroll;
    }

    pub fn placeBet(self: *Player, amount: i32) bool {
        if (!self.canBet(amount)) return false;
        self.bets[0] = amount;
        self.bets[1] = 0;
        self.bankroll -= amount;
        return true;
    }

    // Called when splitting: duplicate the bet into the second hand and
    // deduct the same amount from bankroll (if affordable).
    pub fn applySplitBet(self: *Player) bool {
        const b = self.bets[0];
        if (b <= 0) return false;
        if (b > self.bankroll) return false;
        self.bets[1] = b;
        self.bankroll -= b;
        return true;
    }

    // Payout helpers for individual hands (index 0 or 1)
    pub fn winHand(self: *Player, idx: usize) void {
        self.bankroll += self.bets[idx] * 2;
        self.bets[idx] = 0;
    }

    pub fn loseHand(self: *Player, idx: usize) void {
        self.bets[idx] = 0;
    }

    pub fn pushHand(self: *Player, idx: usize) void {
        self.bankroll += self.bets[idx];
        self.bets[idx] = 0;
    }
};
