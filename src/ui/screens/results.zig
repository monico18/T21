const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const GameState = @import("../../game/state.zig").GameState;
const RoundOutcome = @import("../../game/rules.zig").RoundOutcome;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

// Safe centering helper: returns a signed column suitable for SubSurface.origin
fn center_col(mid: u16, inner_w: u16) i17 {
    const mid_us = @as(usize, mid);
    const half = @as(usize, inner_w) / 2;
    const col_us = if (mid_us > half) mid_us - half else 0;
    return @intCast(col_us);
}

pub const ResultsScreen = struct {
    game: *GameState,
    play_again_btn: ButtonWidget,
    save_btn: ButtonWidget,
    quit_btn: ButtonWidget,
    selected: usize = 0,

    pub fn init(model: *Model, game: *GameState) ResultsScreen {
        // ----------------- PLAY AGAIN -----------------
        const onPlayAgain = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *ResultsScreen = @ptrCast(@alignCast(userdata.?));
                self.game.resetForNextRound();

                // model stored in quit_btn.userdata
                const model_ptr: *Model = @ptrCast(@alignCast(self.quit_btn.userdata.?));

                model_ptr.current_screen = .betting;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // --------------------- SAVE --------------------
        const onSave = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *ResultsScreen = @ptrCast(@alignCast(userdata.?));
                // model stored in quit_btn.userdata
                const model_ptr: *Model = @ptrCast(@alignCast(self.quit_btn.userdata.?));
                try self.game.saveBankrollDefault();
                model_ptr.status.setMessage("Saved.");
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // (Back button removed per request)

        // --------------------- QUIT --------------------
        const onQuit = struct {
            fn cb(_: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                ctx.quit = true;
            }
        }.cb;

        // Return ResultsScreen with play_again_btn.userdata left null. The
        // caller that stores the returned ResultsScreen should set
        // play_again_btn.userdata = &stored_results_screen to avoid taking the
        // address of a stack-local variable here.
        return ResultsScreen{
            .game = game,
            .play_again_btn = .{ .label = "Play Again", .onClick = onPlayAgain, .userdata = null },
            .save_btn = .{ .label = "Save", .onClick = onSave, .userdata = null },
            .quit_btn = .{ .label = "Quit", .onClick = onQuit, .userdata = model },
            .selected = 0,
        };
    }

    pub fn handleEvent(
        self: *ResultsScreen,
        _: *Model,
        ctx: *vxfw.EventContext,
        event: vxfw.Event,
    ) !void {
        switch (event) {
            .init => {
                // Avoid requesting focus during init; rely on navigation to
                // set focus. This prevents vxfw from asserting when the
                // widget path is not yet present.
            },

            .key_press => |key| {
                if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                    ctx.quit = true;
                    return;
                }

                if (key.matches(vaxis.Key.up, .{})) {
                    if (self.selected > 0) self.selected -= 1;
                    try updateFocus(self, ctx);
                    _ = ctx.consumeAndRedraw();
                    return;
                }

                if (key.matches(vaxis.Key.down, .{})) {
                    if (self.selected < 2) self.selected += 1;
                    try updateFocus(self, ctx);
                    _ = ctx.consumeAndRedraw();
                    return;
                }
            },

            else => {},
        }
    }

    fn updateFocus(self: *ResultsScreen, ctx: *vxfw.EventContext) !void {
        switch (self.selected) {
            0 => try ctx.requestFocus(self.play_again_btn.widget()),
            1 => try ctx.requestFocus(self.save_btn.widget()),
            2 => try ctx.requestFocus(self.quit_btn.widget()),
            else => {},
        }
    }

    pub fn draw(self: *ResultsScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const mid = size.width / 2;

        // For split rounds, compute a top-line summary based on per-hand
        // outcomes. This avoids showing a misleading single-hand outcome
        // (which previously used the last processed hand) when multiple
        // hands are present.
        var result_text: []const u8 = "";
        if (self.game.last_hand_count <= 1) {
            const outcome = self.game.last_outcome orelse RoundOutcome.push;
            result_text = switch (outcome) {
                .player_blackjack => "Blackjack! You win!",
                .dealer_blackjack => "Dealer has Blackjack. You lose.",
                .player_win => "You win!",
                .dealer_win => "You lose.",
                .push => "Push.",
            };
        } else {
            // two hands: summarize
            const o0 = self.game.last_outcomes[0];
            const o1 = self.game.last_outcomes[1];
            const both_player = (o0 == RoundOutcome.player_win or o0 == RoundOutcome.player_blackjack) and (o1 == RoundOutcome.player_win or o1 == RoundOutcome.player_blackjack);
            const both_dealer = (o0 == RoundOutcome.dealer_win or o0 == RoundOutcome.dealer_blackjack) and (o1 == RoundOutcome.dealer_win or o1 == RoundOutcome.dealer_blackjack);
            const both_push = (o0 == RoundOutcome.push) and (o1 == RoundOutcome.push);
            if (both_player) {
                result_text = "You won both hands!";
            } else if (both_dealer) {
                result_text = "You lost both hands.";
            } else if (both_push) {
                result_text = "Both hands pushed.";
            } else {
                result_text = "Mixed results.";
            }
        }

        const title = vxfw.Text{ .text = "ROUND RESULTS" };
        const result = vxfw.Text{ .text = result_text };
        // Player lines: if split, show both hands separately with bets.
        var player_line0_surf: ?vxfw.Surface = null;
        var player_line1_surf: ?vxfw.Surface = null;

        // Map per-hand RoundOutcome -> short label for display

        if (self.game.last_hand_count <= 1) {
            const prefix = switch (self.game.last_outcomes[0]) {
                .player_blackjack => "Blackjack!",
                .dealer_blackjack => "Dealer BJ",
                .player_win => "You win",
                .dealer_win => "You lose",
                .push => "Push",
            };
            const player_line = vxfw.Text{
                .text = try std.fmt.allocPrint(
                    ctx.arena,
                    "{s}  Player: Value: {d}   Bet: {d}",
                    .{ prefix, self.game.player.handValue(0), self.game.last_bets[0] },
                ),
            };
            player_line0_surf = try player_line.draw(ctx);
        } else {
            const p0_prefix = switch (self.game.last_outcomes[0]) {
                .player_blackjack => "Blackjack!",
                .dealer_blackjack => "Dealer BJ",
                .player_win => "You win",
                .dealer_win => "You lose",
                .push => "Push",
            };
            const p1_prefix = switch (self.game.last_outcomes[1]) {
                .player_blackjack => "Blackjack!",
                .dealer_blackjack => "Dealer BJ",
                .player_win => "You win",
                .dealer_win => "You lose",
                .push => "Push",
            };
            const p0 = vxfw.Text{
                .text = try std.fmt.allocPrint(ctx.arena, "{s}  Player (1): Value: {d}   Bet: {d}", .{ p0_prefix, self.game.player.handValue(0), self.game.last_bets[0] }),
            };
            const p1 = vxfw.Text{
                .text = try std.fmt.allocPrint(ctx.arena, "{s}  Player (2): Value: {d}   Bet: {d}", .{ p1_prefix, self.game.player.handValue(1), self.game.last_bets[1] }),
            };
            player_line0_surf = try p0.draw(ctx);
            player_line1_surf = try p1.draw(ctx);
        }

        const dealer_line = vxfw.Text{
            .text = try std.fmt.allocPrint(
                ctx.arena,
                "Dealer: {d}   Cards: {d}",
                .{ self.game.dealer.handValue(0), self.game.dealer.hands[0].count },
            ),
        };

        const t_surf = try title.draw(ctx);
        const r_surf = try result.draw(ctx);
        const empty_text = try std.fmt.allocPrint(ctx.arena, "", .{});
        const fallback_surf = try (vxfw.Text{ .text = empty_text }).draw(ctx);
        const p_surf0 = player_line0_surf orelse fallback_surf;
        const p_surf1 = player_line1_surf orelse fallback_surf;
        const d_surf = try dealer_line.draw(ctx);

        const play_surf = try self.play_again_btn.draw(ctx);
        const save_surf = try self.save_btn.draw(ctx);
        const quit_surf = try self.quit_btn.draw(ctx);

        const row_base = size.height / 4;
        const btn_row1 = row_base + 10;
        const btn_row2 = btn_row1 + play_surf.size.height + 2;
        const btn_row3 = btn_row2 + save_surf.size.height + 2;

        // Build children: title, result, player lines (1 or 2), dealer, buttons
        const extra: usize = if (self.game.player.hand_count > 1) 1 else 0;
        const total_children = 4 + extra + 3; // title, result, player0, (player1?), dealer, 3 buttons
        const children = try ctx.arena.alloc(vxfw.SubSurface, total_children);
        var ci: usize = 0;
        children[ci] = .{ .origin = .{ .row = row_base, .col = center_col(mid, @as(u16, t_surf.size.width)) }, .surface = t_surf };
        ci += 1;
        children[ci] = .{ .origin = .{ .row = row_base + 2, .col = center_col(mid, @as(u16, r_surf.size.width)) }, .surface = r_surf };
        ci += 1;
        children[ci] = .{ .origin = .{ .row = row_base + 4, .col = center_col(mid, @as(u16, p_surf0.size.width)) }, .surface = p_surf0 };
        ci += 1;
        if (self.game.player.hand_count > 1) {
            children[ci] = .{ .origin = .{ .row = row_base + 6, .col = center_col(mid, @as(u16, p_surf1.size.width)) }, .surface = p_surf1 };
            ci += 1;
            children[ci] = .{ .origin = .{ .row = row_base + 8, .col = center_col(mid, @as(u16, d_surf.size.width)) }, .surface = d_surf };
            ci += 1;
        } else {
            children[ci] = .{ .origin = .{ .row = row_base + 6, .col = center_col(mid, @as(u16, d_surf.size.width)) }, .surface = d_surf };
            ci += 1;
        }

        children[ci] = .{ .origin = .{ .row = btn_row1, .col = center_col(mid, @as(u16, play_surf.size.width)) }, .surface = play_surf };
        ci += 1;
        children[ci] = .{ .origin = .{ .row = btn_row2, .col = center_col(mid, @as(u16, save_surf.size.width)) }, .surface = save_surf };
        ci += 1;
        children[ci] = .{ .origin = .{ .row = btn_row3, .col = center_col(mid, @as(u16, quit_surf.size.width)) }, .surface = quit_surf };
        ci += 1;

        // debug messages removed

        // Clamp child origins to the surface to prevent unsigned underflow
        // when vaxis computes child regions.
        const max_row: u16 = if (size.height > 0) size.height - 1 else 0;
        const max_col: u16 = if (size.width > 0) size.width - 1 else 0;
        for (children) |*c| {
            if (c.origin.row > max_row) c.origin.row = max_row;
            if (c.origin.col > max_col) c.origin.col = max_col;
        }

        var _empty_results_cells: [0]vaxis.Cell = .{};

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &_empty_results_cells,
            .children = children,
        };
    }
};
