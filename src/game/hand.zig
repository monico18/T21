const std = @import("std");
const Card = @import("card.zig").Card;

pub const Hand = struct {
    cards: [12]Card = undefined, // the most a blackjack hand can hold before bust
    count: usize = 0,

    pub fn reset(self: *Hand) void {
        self.count = 0;
    }

    pub fn addCard(self: *Hand, card: Card) void {
        // Blackjack cannot reach 12 meaningful cards without busting
        if (self.count < self.cards.len) {
            self.cards[self.count] = card;
            self.count += 1;
        }
    }

    pub fn get(self: *Hand, index: usize) ?Card {
        if (index >= self.count) return null;
        return self.cards[index];
    }

    // Return a slice referencing the live hand storage. Use a pointer
    // receiver so the returned slice does not point into a temporary
    // value (value receivers would create a copy and return a slice
    // to stack memory).
    pub fn currentCards(self: *const Hand) []const Card {
        return self.*.cards[0..self.*.count];
    }

    /// Standard Blackjack scoring:
    ///   - Aces count as 11 *unless* that busts the hand
    ///   - Otherwise Aces count as 1
    pub fn value(self: Hand) u8 {
        var total: u8 = 0;
        var aces: u8 = 0;

        // Count base values
        for (self.cards[0..self.count]) |card| {
            total += card.rank.baseValue();
            if (card.rank == .ace) aces += 1;
        }

        // Try to upgrade Aces from 1 → 11 as long as it doesn't bust
        var final_total = total;
        while (aces > 0 and final_total + 10 <= 21) {
            final_total += 10; // one ace becomes 11 instead of 1
            aces -= 1;
        }

        return final_total;
    }

    pub fn isBust(self: Hand) bool {
        return self.value() > 21;
    }

    pub fn isBlackjack(self: Hand) bool {
        return self.count == 2 and self.value() == 21;
    }
};
