const std = @import("std");
const Card = @import("card.zig").Card;
const Suit = @import("card.zig").Suit;
const Rank = @import("card.zig").Rank;

pub const Deck = struct {
    cards: []Card,
    position: usize = 0, // index of next card to deal
    total_cards: usize, // number_of_decks * 52

    pub fn init(allocator: std.mem.Allocator, number_of_decks: usize) !Deck {
        const cards_per_deck = 52;
        const total = number_of_decks * cards_per_deck;

        var cards = try allocator.alloc(Card, total);

        var i: usize = 0;
        for (0..number_of_decks) |_| { // repeat for each deck
            inline for ([_]Suit{ .spades, .hearts, .diamonds, .clubs }) |suit| {
                inline for ([_]Rank{
                    .ace,   .two,  .three, .four, .five,  .six,  .seven,
                    .eight, .nine, .ten,   .jack, .queen, .king,
                }) |rank| {
                    cards[i] = Card{
                        .suit = suit,
                        .rank = rank,
                    };
                    i += 1;
                }
            }
        }

        return .{
            .cards = cards,
            .position = 0,
            .total_cards = total,
        };
    }

    /// Fisher-Yates shuffle (good randomness + linear time)
    pub fn shuffle(self: *Deck) void {
        var prng = std.crypto.random;

        var i: usize = self.total_cards - 1;
        while (i > 0) : (i -= 1) {
            const j = prng.intRangeLessThan(usize, 0, i + 1);
            std.mem.swap(Card, &self.cards[i], &self.cards[j]);
        }

        self.position = 0;
    }

    /// Deals the next card, reshuffling automatically if empty.
    pub fn deal(self: *Deck) Card {
        if (self.position >= self.total_cards) {
            self.shuffle();
        }
        defer self.position += 1;
        return self.cards[self.position];
    }

    /// How many cards remain in the shoe before forcing a reshuffle
    pub fn remaining(self: Deck) usize {
        return self.total_cards - self.position;
    }

    /// Optional free (if game ever resets)
    pub fn deinit(self: *Deck, allocator: std.mem.Allocator) void {
        allocator.free(self.cards);
        self.cards = &.{};
    }
};
