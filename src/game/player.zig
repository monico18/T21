const std = @import("std");
const Hand = @import("hand.zig").Hand;

pub const Player = struct {
    name: []const u8,
    hand: Hand = .{},
    bankroll: i32 = 0,
    bet: i32 = 0,
    is_dealer: bool = false,

    pub fn init(name: []const u8, starting_bankroll: i32, is_dealer: bool) Player {
        return .{
            .name = name,
            .hand = .{},
            .bankroll = starting_bankroll,
            .bet = 0,
            .is_dealer = is_dealer,
        };
    }

    // Reset hand and bet for a new round
    pub fn resetForRound(self: *Player) void {
        self.hand.reset();
        self.bet = 0;
    }

    // Reset only the hand (keep bet intact). Used when starting a round after
    // a bet has already been placed.
    pub fn resetHand(self: *Player) void {
        self.hand.reset();
    }

    // Add a card to this player's hand
    pub fn hit(self: *Player, card: anytype) void {
        self.hand.addCard(card);
    }

    // Check hand value
    pub fn value(self: Player) u8 {
        return self.hand.value();
    }

    pub fn isBust(self: Player) bool {
        return self.hand.isBust();
    }

    pub fn isBlackjack(self: Player) bool {
        return self.hand.isBlackjack();
    }

    pub fn canBet(self: Player, amount: i32) bool {
        return amount > 0 and amount <= self.bankroll;
    }

    pub fn placeBet(self: *Player, amount: i32) bool {
        if (!self.canBet(amount)) return false;
        self.bet = amount;
        self.bankroll -= amount;
        return true;
    }

    pub fn win(self: *Player) void {
        self.bankroll += self.bet * 2;
        self.bet = 0;
    }

    pub fn lose(self: *Player) void {
        self.bet = 0;
    }

    pub fn push(self: *Player) void {
        self.bankroll += self.bet;
        self.bet = 0;
    }
};
