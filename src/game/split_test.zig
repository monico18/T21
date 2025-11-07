const std = @import("std");
const Deck = @import("deck.zig").Deck;
const GameState = @import("state.zig").GameState;
const Player = @import("player.zig").Player;
const Card = @import("card.zig").Card;
const Phase = @import("state.zig").Phase;

test "player split basic" {
    const allocator = std.testing.allocator;

    // Create a deterministic deck (init but do not shuffle)
    const deck = try Deck.init(allocator, 1);
    // don't shuffle: deck.cards order is deterministic from Deck.init

    var gs: GameState = undefined;
    // manually construct minimal game state
    gs.allocator = allocator;
    gs.deck = deck;
    gs.player = Player.init("TestPlayer", 100, false);
    gs.dealer = Player.init("Dealer", 0, true);
    gs.phase = Phase.player_turn;
    gs.last_outcome = null;

    // place a bet
    const ok = gs.player.placeBet(10);
    try std.testing.expect(ok);
    try std.testing.expect(gs.player.bets[0] == 10);
    try std.testing.expect(gs.player.bankroll == 90);

    // Give the player two 8s so splitting is allowed
    gs.player.hands[0].reset();
    gs.player.hands[1].reset();
    gs.player.hands[0].addCard(Card.init(.hearts, .eight));
    gs.player.hands[0].addCard(Card.init(.clubs, .eight));
    gs.player.hand_count = 1;
    gs.player.active_hand = 0;

    // ensure split preconditions
    try std.testing.expect(gs.player.hands[0].count == 2);
    try std.testing.expect(gs.player.hands[0].cards[0].rank == .eight);
    try std.testing.expect(gs.player.hands[0].cards[1].rank == .eight);

    // set deck position to a known place so dealt cards are deterministic
    // choose position near start
    gs.deck.position = 10; // arbitrary safe index

    // perform split
    gs.playerSplit();

    try std.testing.expect(gs.player.hand_count == 2);
    try std.testing.expect(gs.player.bets[1] == 10);
    try std.testing.expect(gs.player.bankroll == 80); // one more bet deducted

    // after split both hands should have 2 cards (original + dealt)
    try std.testing.expect(gs.player.hands[0].count == 2);
    try std.testing.expect(gs.player.hands[1].count == 2);

    // cleanup deck allocation
    gs.deck.deinit(allocator);
}
