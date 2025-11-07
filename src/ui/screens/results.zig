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
    back_btn: ButtonWidget,
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

        // --------------------- BACK --------------------
        const onBack = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *ResultsScreen = @ptrCast(@alignCast(userdata.?));
                // model stored in quit_btn.userdata
                const model_ptr: *Model = @ptrCast(@alignCast(self.quit_btn.userdata.?));
                model_ptr.current_screen = .menu;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

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
            .back_btn = .{ .label = "Back", .onClick = onBack, .userdata = null },
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
                    if (self.selected < 3) self.selected += 1;
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
            2 => try ctx.requestFocus(self.back_btn.widget()),
            3 => try ctx.requestFocus(self.quit_btn.widget()),
            else => {},
        }
    }

    pub fn draw(self: *ResultsScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const mid = size.width / 2;

        const outcome = self.game.last_outcome orelse RoundOutcome.push;

        const result_text = switch (outcome) {
            .player_blackjack => "Blackjack! You win!",
            .dealer_blackjack => "Dealer has Blackjack. You lose.",
            .player_win => "You win!",
            .dealer_win => "You lose.",
            .push => "Push.",
        };

        const title = vxfw.Text{ .text = "ROUND RESULTS" };
        const result = vxfw.Text{ .text = result_text };
        const player_line = vxfw.Text{
            .text = try std.fmt.allocPrint(
                ctx.arena,
                "Player: {d}   Cards: {d}",
                .{ self.game.player.hand.value(), self.game.player.hand.count },
            ),
        };
        const dealer_line = vxfw.Text{
            .text = try std.fmt.allocPrint(
                ctx.arena,
                "Dealer: {d}   Cards: {d}",
                .{ self.game.dealer.hand.value(), self.game.dealer.hand.count },
            ),
        };

        const t_surf = try title.draw(ctx);
        const r_surf = try result.draw(ctx);
        const p_surf = try player_line.draw(ctx);
        const d_surf = try dealer_line.draw(ctx);

        const play_surf = try self.play_again_btn.draw(ctx);
        const save_surf = try self.save_btn.draw(ctx);
        const back_surf = try self.back_btn.draw(ctx);
        const quit_surf = try self.quit_btn.draw(ctx);

        const row_base = size.height / 4;
        const btn_row1 = row_base + 10;
        const btn_row2 = btn_row1 + play_surf.size.height + 2;
        const btn_row3 = btn_row2 + save_surf.size.height + 2;

        const children = try ctx.arena.alloc(vxfw.SubSurface, 8);
        children[0] = .{ .origin = .{ .row = row_base, .col = center_col(mid, @as(u16, t_surf.size.width)) }, .surface = t_surf };
        children[1] = .{ .origin = .{ .row = row_base + 2, .col = center_col(mid, @as(u16, r_surf.size.width)) }, .surface = r_surf };
        children[2] = .{ .origin = .{ .row = row_base + 4, .col = center_col(mid, @as(u16, p_surf.size.width)) }, .surface = p_surf };
        children[3] = .{ .origin = .{ .row = row_base + 6, .col = center_col(mid, @as(u16, d_surf.size.width)) }, .surface = d_surf };
        children[4] = .{ .origin = .{ .row = btn_row1, .col = center_col(mid, @as(u16, play_surf.size.width)) }, .surface = play_surf };
        children[5] = .{ .origin = .{ .row = btn_row2, .col = center_col(mid, @as(u16, save_surf.size.width)) }, .surface = save_surf };
        children[6] = .{ .origin = .{ .row = btn_row3, .col = center_col(mid, @as(u16, back_surf.size.width)) }, .surface = back_surf };
        children[7] = .{ .origin = .{ .row = btn_row3 + back_surf.size.height + 2, .col = center_col(mid, @as(u16, quit_surf.size.width)) }, .surface = quit_surf };

        // Debug: report any out-of-bounds child origins before clamping.
        for (children) |c| {
            if (c.origin.row > size.height or c.origin.col > size.width) {
                std.debug.print("[results] child origin out-of-bounds: row={d} col={d} surface={d}x{d} size={d}x{d}\n", .{ c.origin.row, c.origin.col, c.surface.size.width, c.surface.size.height, size.width, size.height });
            }
        }

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
