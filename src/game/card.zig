const std = @import("std");

pub const Suit = enum {
    hearts,
    diamonds,
    clubs,
    spades,

    pub fn symbol(self: Suit) []const u8 {
        return switch (self) {
            .hearts => "♥",
            .diamonds => "♦",
            .clubs => "♣",
            .spades => "♠",
        };
    }

    pub fn isRed(self: Suit) bool {
        return switch (self) {
            .hearts, .diamonds => true,
            .clubs, .spades => false,
        };
    }
};

pub const Rank = enum {
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    ten,
    jack,
    queen,
    king,
    ace,

    /// Returns the Blackjack *base* value of the rank.
    /// Ace is treated as 1 here — flexibility handled in `hand.zig`
    pub fn baseValue(self: Rank) u8 {
        return @as(u8, switch (self) {
            .two => 2,
            .three => 3,
            .four => 4,
            .five => 5,
            .six => 6,
            .seven => 7,
            .eight => 8,
            .nine => 9,
            .ten, .jack, .queen, .king => 10,
            .ace => 1,
        });
    }

    pub fn label(self: Rank) []const u8 {
        return switch (self) {
            .two => "2",
            .three => "3",
            .four => "4",
            .five => "5",
            .six => "6",
            .seven => "7",
            .eight => "8",
            .nine => "9",
            .ten => "10",
            .jack => "J",
            .queen => "Q",
            .king => "K",
            .ace => "A",
        };
    }
};

pub const Card = struct {
    suit: Suit,
    rank: Rank,

    pub fn init(suit: Suit, rank: Rank) Card {
        return .{ .suit = suit, .rank = rank };
    }

    pub fn shortString(self: Card, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{s}{u}",
            .{ self.rank.label(), self.suit.symbol() },
        );
    }
};
