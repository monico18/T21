const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const GameState = @import("../../game/state.zig").GameState;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

pub const BettingScreen = struct {
    game: *GameState,
    model: *Model,

    bet: i32 = 10,

    plus_btn: ButtonWidget,
    minus_btn: ButtonWidget,
    confirm_btn: ButtonWidget,
    back_btn: ButtonWidget,

    selected: usize = 0,

    pub fn init(model: *Model, game: *GameState) !BettingScreen {

        // +1 button
        const onPlus = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet += 1;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // -1 button
        const onMinus = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                if (self.bet > 1) self.bet -= 1;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // Confirm button → go to table if bet allowed
        const onConfirm = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));

                if (!self.game.player.canBet(self.bet)) {
                    _ = ctx.consumeAndRedraw();
                    return;
                }

                _ = self.game.placeBet(self.bet);
                self.game.beginRound();

                self.model.current_screen = .table;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // Back → menu
        const onBack = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.model.current_screen = .menu;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // Create screen struct
        // Return a BettingScreen with button userdata left null. Caller must
        // set the userdata pointers after storing the returned value.
        return BettingScreen{
            .game = game,
            .model = model,
            .bet = 10,

            .plus_btn = .{ .label = "+1", .onClick = onPlus, .userdata = null },
            .minus_btn = .{ .label = "-1", .onClick = onMinus, .userdata = null },
            .confirm_btn = .{ .label = "Confirm", .onClick = onConfirm, .userdata = null },
            .back_btn = .{ .label = "Back", .onClick = onBack, .userdata = null },

            .selected = 0,
        };
    }

    pub fn handleEvent(self: *BettingScreen, _: *Model, ctx: *vxfw.EventContext, event: vxfw.Event) !void {
        switch (event) {
            .init => {
                // See note in menu.init: avoid requesting focus here to
                // prevent focus-path assertion if the widget tree isn't
                // available yet.
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

                if (key.matches('+', .{})) {
                    self.bet += 1;
                    _ = ctx.consumeAndRedraw();
                    return;
                }

                if (key.matches('-', .{})) {
                    if (self.bet > 1) self.bet -= 1;
                    _ = ctx.consumeAndRedraw();
                    return;
                }
            },
            else => {},
        }
    }

    fn updateFocus(self: *BettingScreen, ctx: *vxfw.EventContext) !void {
        switch (self.selected) {
            0 => {
                std.debug.print("[betting] updateFocus: requesting focus on plus_btn\n", .{});
                try ctx.requestFocus(self.plus_btn.widget());
            },
            1 => {
                std.debug.print("[betting] updateFocus: requesting focus on minus_btn\n", .{});
                try ctx.requestFocus(self.minus_btn.widget());
            },
            2 => {
                std.debug.print("[betting] updateFocus: requesting focus on confirm_btn\n", .{});
                try ctx.requestFocus(self.confirm_btn.widget());
            },
            3 => {
                std.debug.print("[betting] updateFocus: requesting focus on back_btn\n", .{});
                try ctx.requestFocus(self.back_btn.widget());
            },
            else => {},
        }
    }

    pub fn draw(self: *BettingScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const mid = size.width / 2;

        const title = vxfw.Text{ .text = "PLACE YOUR BET" };
        const bank = vxfw.Text{
            .text = try std.fmt.allocPrint(ctx.arena, "Bankroll: {d}", .{self.game.player.bankroll}),
        };
        const bet = vxfw.Text{
            .text = try std.fmt.allocPrint(ctx.arena, "Bet:      {d}", .{self.bet}),
        };

        const t_surf = try title.draw(ctx);
        const b_surf = try bank.draw(ctx);
        const bet_surf = try bet.draw(ctx);

        const plus_surf = try self.plus_btn.draw(ctx);
        const minus_surf = try self.minus_btn.draw(ctx);
        const confirm_surf = try self.confirm_btn.draw(ctx);
        const back_surf = try self.back_btn.draw(ctx);

        const y_title = size.height / 8;
        const y_bank = y_title + 2;
        const y_bet = y_bank + 2;

        const row1 = size.height / 2 - 3;
        const row2 = row1 + plus_surf.size.height + 2;
        const row3 = row2 + confirm_surf.size.height + 2;

        const children = try ctx.arena.alloc(vxfw.SubSurface, 7);
        children[0] = .{ .origin = .{ .row = y_title, .col = mid - (t_surf.size.width / 2) }, .surface = t_surf };
        children[1] = .{ .origin = .{ .row = y_bank, .col = mid - (b_surf.size.width / 2) }, .surface = b_surf };
        children[2] = .{ .origin = .{ .row = y_bet, .col = mid - (bet_surf.size.width / 2) }, .surface = bet_surf };
        children[3] = .{ .origin = .{ .row = row1, .col = mid - plus_surf.size.width - 2 }, .surface = plus_surf };
        children[4] = .{ .origin = .{ .row = row1, .col = mid + 2 }, .surface = minus_surf };
        children[5] = .{ .origin = .{ .row = row2, .col = mid - (confirm_surf.size.width / 2) }, .surface = confirm_surf };
        children[6] = .{ .origin = .{ .row = row3, .col = mid - (back_surf.size.width / 2) }, .surface = back_surf };

        var _empty_betting_cells: [0]vaxis.Cell = .{};

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &_empty_betting_cells,
            .children = children,
        };
    }
};
