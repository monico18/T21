const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const GameState = @import("../../game/state.zig").GameState;

const HandWidget = @import("../widgets/hand_widget.zig").HandWidget;
const StatusWidget = @import("../widgets/status_widget.zig").StatusWidget;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

pub const TableScreen = struct {
    game: *GameState,

    hit_btn: ButtonWidget,
    stand_btn: ButtonWidget,
    double_btn: ButtonWidget,

    selected: usize = 0,

    pub fn init(game: *GameState) TableScreen {
        const onHit = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *TableScreen = @ptrCast(@alignCast(userdata.?));
                self.game.playerHit();
                return ctx.consumeAndRedraw();
            }
        }.cb;

        const onStand = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *TableScreen = @ptrCast(@alignCast(userdata.?));
                self.game.playerStand();
                return ctx.consumeAndRedraw();
            }
        }.cb;

        const onDouble = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *TableScreen = @ptrCast(@alignCast(userdata.?));
                self.game.playerDouble();
                return ctx.consumeAndRedraw();
            }
        }.cb;

        // Construct a TableScreen with button userdata left null. The
        // caller must assign the button userdata to the address of the
        // final stored TableScreen (e.g. &model.table_screen) to avoid
        // taking the address of a stack-local value.
        return TableScreen{
            .game = game,
            .hit_btn = .{ .label = "Hit", .onClick = onHit, .userdata = null },
            .stand_btn = .{ .label = "Stand", .onClick = onStand, .userdata = null },
            .double_btn = .{ .label = "Double", .onClick = onDouble, .userdata = null },
            .selected = 0,
        };
    }

    pub fn handleEvent(
        self: *TableScreen,
        model: *Model,
        ctx: *vxfw.EventContext,
        event: vxfw.Event,
    ) !void {
        switch (event) {
            .init => try ctx.requestFocus(self.hit_btn.widget()),

            .key_press => |key| {
                const phase = self.game.phase;

                if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                    ctx.quit = true;
                    return;
                }

                if (phase == .player_turn) {
                    if (key.matches(vaxis.Key.left, .{})) {
                        if (self.selected > 0) self.selected -= 1;
                        try updateFocus(self, ctx);
                        _ = ctx.consumeAndRedraw();
                        return;
                    }
                    if (key.matches(vaxis.Key.right, .{})) {
                        if (self.selected < 2) self.selected += 1;
                        try updateFocus(self, ctx);
                        _ = ctx.consumeAndRedraw();
                        return;
                    }

                    if (key.matches('h', .{})) {
                        self.game.playerHit();
                        _ = ctx.consumeAndRedraw();
                        return;
                    }
                    if (key.matches('s', .{})) {
                        self.game.playerStand();
                        _ = ctx.consumeAndRedraw();
                        return;
                    }
                    if (key.matches('d', .{})) {
                        self.game.playerDouble();
                        _ = ctx.consumeAndRedraw();
                        return;
                    }
                }

                if (phase == .results) {
                    model.current_screen = .results;
                    _ = ctx.consumeAndRedraw();
                    return;
                }
            },

            else => {},
        }
    }

    fn updateFocus(self: *TableScreen, ctx: *vxfw.EventContext) !void {
        switch (self.selected) {
            0 => try ctx.requestFocus(self.hit_btn.widget()),
            1 => try ctx.requestFocus(self.stand_btn.widget()),
            2 => try ctx.requestFocus(self.double_btn.widget()),
            else => {},
        }
    }

    pub fn draw(self: *TableScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const game = self.game;

        // Dealer hand --------------------------------------------------------
        const hide_first = (game.phase == .player_turn);
        var dealer_hand = HandWidget.init(game.dealer.hand.currentCards(), hide_first);
        const dealer_surf = try dealer_hand.widget().drawFn(&dealer_hand, ctx);

        var dealer_x: u16 = 0;
        if (size.width > dealer_surf.size.width) {
            dealer_x = (size.width - dealer_surf.size.width) / 2;
        }
        const dealer_y: u16 = 2;

        const dealer_sub = vxfw.SubSurface{
            .origin = .{ .row = dealer_y, .col = dealer_x },
            .surface = dealer_surf,
        };

        // Player hand --------------------------------------------------------
        var player_hand = HandWidget.init(game.player.hand.currentCards(), false);
        const player_surf = try player_hand.widget().drawFn(&player_hand, ctx);

        var player_x: u16 = 0;
        if (size.width > player_surf.size.width) {
            player_x = (size.width - player_surf.size.width) / 2;
        }
        const player_y: u16 = if (size.height > player_surf.size.height + 8) size.height - (player_surf.size.height + 8) else 0;

        const player_sub = vxfw.SubSurface{
            .origin = .{ .row = player_y, .col = player_x },
            .surface = player_surf,
        };

        // Status widget ------------------------------------------------------
        var status_ptr = &model.status;
        const status_surf = try status_ptr.widget().drawFn(status_ptr, ctx);

        var status_x: u16 = 0;
        if (size.width > status_surf.size.width) {
            status_x = (size.width - status_surf.size.width) / 2;
        }
        const status_y: u16 = if (size.height > status_surf.size.height + 1) size.height - (status_surf.size.height + 1) else 0;

        const status_sub = vxfw.SubSurface{
            .origin = .{ .row = status_y, .col = status_x },
            .surface = status_surf,
        };

        // Buttons ------------------------------------------------------------
        var count: usize = 3;
        var hit_sub: vxfw.SubSurface = undefined;
        var stand_sub: vxfw.SubSurface = undefined;
        var double_sub: vxfw.SubSurface = undefined;

        if (game.phase == .player_turn) {
            const hit_surf = try self.hit_btn.draw(ctx);
            const stand_surf = try self.stand_btn.draw(ctx);
            const double_surf = try self.double_btn.draw(ctx);

            const base_row = player_y + player_surf.size.height + 2;
            const mid = size.width / 2;

            hit_sub = .{
                .origin = .{ .row = base_row, .col = mid - 20 },
                .surface = hit_surf,
            };
            stand_sub = .{
                .origin = .{ .row = base_row, .col = mid - (stand_surf.size.width / 2) },
                .surface = stand_surf,
            };
            double_sub = .{
                .origin = .{ .row = base_row, .col = mid + 20 },
                .surface = double_surf,
            };

            count += 3;
        }

        const children = try ctx.arena.alloc(vxfw.SubSurface, count);
        children[0] = dealer_sub;
        children[1] = player_sub;
        children[2] = status_sub;

        if (game.phase == .player_turn) {
            children[3] = hit_sub;
            children[4] = stand_sub;
            children[5] = double_sub;
        }

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &.{},
            .children = children,
        };
    }
};
