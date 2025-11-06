const std = @import("std");
const Player = @import("player.zig").Player;
const Hand = @import("hand.zig").Hand;

pub const RoundOutcome = enum {
    player_blackjack,
    dealer_blackjack,
    player_win,
    dealer_win,
    push,
};

/// Dealer must hit until 17 or more.
/// A “soft 17” (Ace counted as 11) is treated as **hit again** by casino rules.
/// If you want dealer to stand on soft 17, we can toggle this later.
pub fn dealerShouldHit(hand: Hand) bool {
    const v = hand.value();

    if (v < 17) return true;

    // detect soft 17 (value == 17 AND contains an ace used as 11)
    if (v == 17 and isSoft(hand)) return true;

    return false;
}

/// A hand is “soft” if it contains an Ace counted as 11
pub fn isSoft(hand: Hand) bool {
    var total: u8 = 0;
    var aces: u8 = 0;

    for (hand.currentCards()) |c| {
        total += c.rank.baseValue();
        if (c.rank == .ace) aces += 1;
    }

    // If upgrading an Ace would create total<=21, it's a soft hand
    return aces > 0 and (total + 10) <= 21;
}

/// Determine the outcome of a finished round.
pub fn determineOutcome(player: Player, dealer: Player) RoundOutcome {
    const p_val = player.hand.value();
    const d_val = dealer.hand.value();

    // Immediate blackjack checks (2 cards only)
    const p_bj = player.isBlackjack();
    const d_bj = dealer.isBlackjack();

    if (p_bj and d_bj) return .push;
    if (p_bj) return .player_blackjack;
    if (d_bj) return .dealer_blackjack;

    // Busts
    if (player.isBust()) return .dealer_win;
    if (dealer.isBust()) return .player_win;

    // Normal comparison
    if (p_val > d_val) return .player_win;
    if (p_val < d_val) return .dealer_win;

    return .push;
}

/// Apply bankroll changes based on the result.
/// This assumes bet was already deducted before the round begins.
pub fn applyPayout(player: *Player, outcome: RoundOutcome) void {
    switch (outcome) {
        .player_blackjack => {
            // Blackjack usually pays 3:2 → bet*2.5 (or 6:5 in some casinos)
            // Using 3:2 here:
            player.bankroll += player.bet + @divTrunc(player.bet * 3, 2);
            player.bet = 0;
        },
        .dealer_blackjack => {
            // player already lost bet
            player.bet = 0;
        },
        .player_win => {
            player.win();
        },
        .dealer_win => {
            player.lose();
        },
        .push => {
            player.push();
        },
    }
}
