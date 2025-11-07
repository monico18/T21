const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const GameState = @import("../../game/state.zig").GameState;

const HandWidget = @import("../widgets/hand_widget.zig").HandWidget;
const StatusWidget = @import("../widgets/status_widget.zig").StatusWidget;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

// Safe centering helper: returns a signed column suitable for SubSurface.origin
fn center_col(mid: u16, inner_w: u16) i17 {
    const mid_us = @as(usize, mid);
    const half = @as(usize, inner_w) / 2;
    const col_us = if (mid_us > half) mid_us - half else 0;
    return @intCast(col_us);
}

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
            .init => {
                // Do not request focus here; requesting focus during init can
                // cause vxfw to assert if the requested widget is not yet
                // present in the drawn widget tree. Navigation will set
                // focus when appropriate.
            },

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
            0 => {
                std.debug.print("[table] updateFocus: requesting focus on hit_btn\n", .{});
                try ctx.requestFocus(self.hit_btn.widget());
            },
            1 => {
                std.debug.print("[table] updateFocus: requesting focus on stand_btn\n", .{});
                try ctx.requestFocus(self.stand_btn.widget());
            },
            2 => {
                std.debug.print("[table] updateFocus: requesting focus on double_btn\n", .{});
                try ctx.requestFocus(self.double_btn.widget());
            },
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

        // Dealer points label: when the dealer's first card is hidden (during
        // the player's turn) only show the total for face-up cards.
        const dealer_cards = game.dealer.hand.currentCards();
        var visible_total: u8 = 0;
        var visible_aces: u8 = 0;
        var idx: usize = 0;
        while (idx < dealer_cards.len) : (idx += 1) {
            if (hide_first and idx == 0) continue;
            const c = dealer_cards[idx];
            visible_total += c.rank.baseValue();
            if (c.rank == .ace) visible_aces += 1;
        }
        var final_total: u8 = visible_total;
        while (visible_aces > 0 and final_total + 10 <= 21) : (visible_aces -= 1) {
            final_total += 10;
        }

        const dealer_points_text = try std.fmt.allocPrint(ctx.arena, "Dealer: {d}", .{final_total});
        const dealer_points_widget = vxfw.Text{ .text = dealer_points_text };
        const dealer_points_surf = try dealer_points_widget.draw(ctx);
        const dealer_label_row: u16 = if (dealer_y > 0) dealer_y - 1 else dealer_y;
        // compute dealer label column safely to avoid unsigned underflow
        const dealer_label_col: u16 = @intCast((if (@as(usize, dealer_x) + (@as(usize, dealer_surf.size.width) / 2) > (@as(usize, dealer_points_surf.size.width) / 2))
            @as(usize, dealer_x) + (@as(usize, dealer_surf.size.width) / 2) - (@as(usize, dealer_points_surf.size.width) / 2)
        else
            0));
        const dealer_label_sub = vxfw.SubSurface{
            .origin = .{ .row = dealer_label_row, .col = dealer_label_col },
            .surface = dealer_points_surf,
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

        // Player points label
        const player_points_text = try std.fmt.allocPrint(ctx.arena, "Player: {d}", .{game.player.value()});
        const player_points_widget = vxfw.Text{ .text = player_points_text };
        const player_points_surf = try player_points_widget.draw(ctx);
        const player_label_row: u16 = if (player_y > 0) player_y - 1 else player_y;
        const player_label_col: u16 = @intCast((if (@as(usize, player_x) + (@as(usize, player_surf.size.width) / 2) > (@as(usize, player_points_surf.size.width) / 2))
            @as(usize, player_x) + (@as(usize, player_surf.size.width) / 2) - (@as(usize, player_points_surf.size.width) / 2)
        else
            0));
        const player_label_sub = vxfw.SubSurface{
            .origin = .{ .row = player_label_row, .col = player_label_col },
            .surface = player_points_surf,
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
        // children: dealer label, dealer hand, player label, player hand, status
        var count: usize = 5;
        var hit_sub: vxfw.SubSurface = undefined;
        var stand_sub: vxfw.SubSurface = undefined;
        var double_sub: vxfw.SubSurface = undefined;

        if (game.phase == .player_turn) {
            const hit_surf = try self.hit_btn.draw(ctx);
            const stand_surf = try self.stand_btn.draw(ctx);
            const double_surf = try self.double_btn.draw(ctx);

            const base_row = player_y + player_surf.size.height + 2;
            const mid = size.width / 2;

            // compute columns safely to avoid unsigned underflow
            const hit_col: u16 = if (mid > 20) mid - 20 else 0;
            const stand_col: u16 = @intCast((if (@as(usize, mid) > (@as(usize, stand_surf.size.width) / 2)) @as(usize, mid) - (@as(usize, stand_surf.size.width) / 2) else 0));
            const double_col: u16 = if (@as(usize, mid) + 20 < @as(usize, 0xFFFF)) @intCast(@as(usize, mid) + 20) else @intCast(@as(usize, mid));

            hit_sub = .{
                .origin = .{ .row = base_row, .col = hit_col },
                .surface = hit_surf,
            };
            stand_sub = .{
                .origin = .{ .row = base_row, .col = stand_col },
                .surface = stand_surf,
            };
            double_sub = .{
                .origin = .{ .row = base_row, .col = double_col },
                .surface = double_surf,
            };

            count += 3;
        }

        const children = try ctx.arena.alloc(vxfw.SubSurface, count);
        children[0] = dealer_label_sub;
        children[1] = dealer_sub;
        children[2] = player_label_sub;
        children[3] = player_sub;
        children[4] = status_sub;

        if (game.phase == .player_turn) {
            // append buttons after existing children
            children[5] = hit_sub;
            children[6] = stand_sub;
            children[7] = double_sub;
        }

        // Debug: report any out-of-bounds child origins before clamping.
        for (children) |c| {
            if (c.origin.row > size.height or c.origin.col > size.width) {
                std.debug.print("[table] child origin out-of-bounds: row={d} col={d} surface={d}x{d} size={d}x{d}\n", .{ c.origin.row, c.origin.col, c.surface.size.width, c.surface.size.height, size.width, size.height });
            }
        }

        // Clamp children origins to avoid unsigned underflow in vaxis
        const max_row: u16 = if (size.height > 0) size.height - 1 else 0;
        const max_col: u16 = if (size.width > 0) size.width - 1 else 0;
        for (children) |*c| {
            if (c.origin.row > max_row) c.origin.row = max_row;
            if (c.origin.col > max_col) c.origin.col = max_col;
        }

        var _empty_table_cells: [0]vaxis.Cell = .{};

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &_empty_table_cells,
            .children = children,
        };
    }
};
