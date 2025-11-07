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

// Create a small multi-line surface representing a hand box: label, cards, bet.
fn make_hand_box(ctx: vxfw.DrawContext, label: []const u8, value: u8, bet: i32, style: ?*const vaxis.Style) !vxfw.Surface {
    const text = try std.fmt.allocPrint(ctx.arena, "{s}\nValue: {d}\nBet: {d}", .{ label, value, bet });
    if (style) |s| {
        const t = vxfw.Text{ .text = text, .style = s.* };
        return t.draw(ctx);
    } else {
        const t = vxfw.Text{ .text = text };
        return t.draw(ctx);
    }
}

pub const TableScreen = struct {
    game: *GameState,

    hit_btn: ButtonWidget,
    stand_btn: ButtonWidget,
    double_btn: ButtonWidget,
    split_btn: ButtonWidget,

    selected: usize = 0,
    blink_counter: u8 = 0,

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

        const onSplit = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *TableScreen = @ptrCast(@alignCast(userdata.?));
                self.game.playerSplit();
                return ctx.consumeAndRedraw();
            }
        }.cb;

        // Construct a TableScreen with button userdata left null. The
        // caller must assign the button userdata to the address of the
        // final stored TableScreen (e.g. &model.table_screen) to avoid
        // taking the address of a stack-local value.
        return TableScreen{
            .game = game,
            .hit_btn = .{ .label = "[H]it", .onClick = onHit, .userdata = null },
            .stand_btn = .{ .label = "[S]tand", .onClick = onStand, .userdata = null },
            .double_btn = .{ .label = "[D]ouble", .onClick = onDouble, .userdata = null },
            .split_btn = .{ .label = "Spli[t]", .onClick = onSplit, .userdata = null },
            .selected = 0,
            .blink_counter = 0,
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
                        if (self.selected < 3) self.selected += 1;
                        try updateFocus(self, ctx);
                        _ = ctx.consumeAndRedraw();
                        return;
                    }

                    // quick hand selection when split: keys '1' and '2'
                    if (key.matches('1', .{})) {
                        if (self.game.player.hand_count > 0) {
                            self.game.player.active_hand = 0;
                            _ = ctx.consumeAndRedraw();
                            return;
                        }
                    }
                    if (key.matches('2', .{})) {
                        if (self.game.player.hand_count > 1) {
                            self.game.player.active_hand = 1;
                            _ = ctx.consumeAndRedraw();
                            return;
                        }
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
                    if (key.matches('t', .{})) {
                        self.game.playerSplit();
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
            3 => try ctx.requestFocus(self.split_btn.widget()),
            else => {},
        }
    }

    pub fn draw(self: *TableScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const game = self.game;

        // Dealer hand --------------------------------------------------------
        const hide_first = (game.phase == .player_turn);
        var dealer_hand = HandWidget.init((&game.dealer.hands[0]).currentCards(), hide_first);
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
        const dealer_cards = (&game.dealer.hands[0]).currentCards();
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
        // Blinking indicator counter (simple frame-based blink)
        self.blink_counter = @as(u8, (self.blink_counter + 1) % 30);
        const blink_on = (self.blink_counter < 15);

        // Player hands: support one or two hands (split). When split, render
        // the two hands side-by-side along with their bets and an active
        // hand indicator that blinks. Additionally render a centered box or
        // two boxes in the middle of the screen that show each hand's card
        // count and bet; highlight the active hand's box.
        const spacing: u16 = 4;

        var player_sub: vxfw.SubSurface = undefined;
        var player_label_sub: vxfw.SubSurface = undefined;
        var player_label_sub_1: vxfw.SubSurface = undefined;
        // optional second hand subs/bet/indicator
        var player_sub_1: vxfw.SubSurface = undefined;
        var bet_sub_0: vxfw.SubSurface = undefined;
        var bet_sub_1: vxfw.SubSurface = undefined;
        var active_sub: vxfw.SubSurface = undefined;
        var active_present: bool = false;

        // normalize player_y and a representative player_surf.size for later
        var player_y: u16 = 0;
        var player_surf_height: u16 = 0;

        // (hand box helper is top-level to avoid nested-function parsing issues)

        if (game.player.hand_count <= 1) {
            var player_hand = HandWidget.init((&game.player.hands[0]).currentCards(), false);
            const player_surf = try player_hand.widget().drawFn(&player_hand, ctx);

            var player_x: u16 = 0;
            if (size.width > player_surf.size.width) {
                player_x = (size.width - player_surf.size.width) / 2;
            }
            player_y = if (size.height > player_surf.size.height + 8) size.height - (player_surf.size.height + 8) else 0;

            player_sub = vxfw.SubSurface{
                .origin = .{ .row = player_y, .col = player_x },
                .surface = player_surf,
            };
            player_surf_height = player_surf.size.height;

            // Create a centered box in the middle of the screen showing count & bet
            const box_style: ?*const vaxis.Style = null;
            const box_surf = try make_hand_box(ctx, "Player", @as(u8, game.player.handValue(game.player.active_hand)), game.player.bets[0], box_style);
            const box_row: u16 = @intCast((@as(usize, size.height) / 2) - (@as(usize, box_surf.size.height) / 2));
            const box_col: u16 = @intCast((@as(usize, size.width) / 2) - (@as(usize, box_surf.size.width) / 2));
            player_label_sub = vxfw.SubSurface{ .origin = .{ .row = box_row, .col = box_col }, .surface = box_surf };
        } else {
            // two hands: draw both and center them together
            var hand0 = HandWidget.init((&game.player.hands[0]).currentCards(), false);
            var hand1 = HandWidget.init((&game.player.hands[1]).currentCards(), false);
            const surf0 = try hand0.widget().drawFn(&hand0, ctx);
            const surf1 = try hand1.widget().drawFn(&hand1, ctx);

            const total_w_us: usize = @as(usize, surf0.size.width) + @as(usize, surf1.size.width) + @as(usize, spacing);
            var base_x_us: usize = 0;
            if (@as(usize, size.width) > total_w_us) base_x_us = (@as(usize, size.width) - total_w_us) / 2;

            player_y = if (size.height > (@max(surf0.size.height, surf1.size.height) + 8)) size.height - (@max(surf0.size.height, surf1.size.height) + 8) else 0;

            player_sub = vxfw.SubSurface{ .origin = .{ .row = player_y, .col = @intCast(base_x_us) }, .surface = surf0 };
            player_sub_1 = vxfw.SubSurface{ .origin = .{ .row = player_y, .col = @intCast(base_x_us + @as(usize, surf0.size.width) + @as(usize, spacing)) }, .surface = surf1 };
            player_surf_height = @max(surf0.size.height, surf1.size.height);

            // Bets under each hand (kept for compatibility) and box display
            const bet0_text = try std.fmt.allocPrint(ctx.arena, "Bet: {d}", .{game.player.bets[0]});
            const bet1_text = try std.fmt.allocPrint(ctx.arena, "Bet: {d}", .{game.player.bets[1]});
            const bet0_widget = vxfw.Text{ .text = bet0_text };
            const bet1_widget = vxfw.Text{ .text = bet1_text };
            const bet0_surf = try bet0_widget.draw(ctx);
            const bet1_surf = try bet1_widget.draw(ctx);

            const bet_row: u16 = player_y + @max(surf0.size.height, surf1.size.height) + 1;
            const bet0_col_us: usize = if (@as(usize, base_x_us) + (@as(usize, surf0.size.width) / 2) > (@as(usize, bet0_surf.size.width) / 2)) @as(usize, base_x_us) + (@as(usize, surf0.size.width) / 2) - (@as(usize, bet0_surf.size.width) / 2) else 0;
            const bet1_col_us: usize = if (@as(usize, base_x_us + @as(usize, surf0.size.width) + @as(usize, spacing)) + (@as(usize, surf1.size.width) / 2) > (@as(usize, bet1_surf.size.width) / 2)) @as(usize, base_x_us + @as(usize, surf0.size.width) + @as(usize, spacing)) + (@as(usize, surf1.size.width) / 2) - (@as(usize, bet1_surf.size.width) / 2) else 0;
            const bet0_col: u16 = @intCast(bet0_col_us);
            const bet1_col: u16 = @intCast(bet1_col_us);

            bet_sub_0 = vxfw.SubSurface{ .origin = .{ .row = bet_row, .col = bet0_col }, .surface = bet0_surf };
            bet_sub_1 = vxfw.SubSurface{ .origin = .{ .row = bet_row, .col = bet1_col }, .surface = bet1_surf };

            // Active-hand indicator (above the chosen hand). Blink when active.
            if (blink_on) {
                const active_text = try std.fmt.allocPrint(ctx.arena, "ACTIVE", .{});
                const active_widget = vxfw.Text{ .text = active_text };
                const active_surf = try active_widget.draw(ctx);
                const active_row: u16 = if (player_y > 0) player_y - 1 else 0;
                const active_col_us: usize = if (game.player.active_hand == 0)
                    if (@as(usize, base_x_us) + (@as(usize, surf0.size.width) / 2) > (@as(usize, active_surf.size.width) / 2)) @as(usize, base_x_us) + (@as(usize, surf0.size.width) / 2) - (@as(usize, active_surf.size.width) / 2) else 0
                else if (@as(usize, base_x_us + @as(usize, surf0.size.width) + @as(usize, spacing)) + (@as(usize, surf1.size.width) / 2) > (@as(usize, active_surf.size.width) / 2)) @as(usize, base_x_us + @as(usize, surf0.size.width) + @as(usize, spacing)) + (@as(usize, surf1.size.width) / 2) - (@as(usize, active_surf.size.width) / 2) else 0;
                active_sub = vxfw.SubSurface{ .origin = .{ .row = active_row, .col = @intCast(active_col_us) }, .surface = active_surf };
                active_present = true;
            }

            // When split, show two boxes side-by-side in the center with counts and bets
            const label0 = try std.fmt.allocPrint(ctx.arena, "Hand 1", .{});
            const label1 = try std.fmt.allocPrint(ctx.arena, "Hand 2", .{});
            var active_style0: vaxis.Style = vaxis.Style{};
            var active_style1: vaxis.Style = vaxis.Style{};
            if (game.player.active_hand == 0) active_style0 = vaxis.Style{ .fg = vaxis.Color{ .rgb = [3]u8{ 0x00, 0xFF, 0x00 } } };
            if (game.player.active_hand == 1) active_style1 = vaxis.Style{ .fg = vaxis.Color{ .rgb = [3]u8{ 0x00, 0xFF, 0x00 } } };
            const box0 = try make_hand_box(ctx, label0, game.player.handValue(0), game.player.bets[0], &active_style0);
            const box1 = try make_hand_box(ctx, label1, game.player.handValue(1), game.player.bets[1], &active_style1);
            const box_row: u16 = @intCast((@as(usize, size.height) / 2) - (@as(usize, @max(box0.size.height, box1.size.height)) / 2));
            const box0_col: u16 = @intCast(base_x_us + (@as(usize, surf0.size.width) / 2) - (@as(usize, box0.size.width) / 2));
            const box1_col: u16 = @intCast(base_x_us + @as(usize, surf0.size.width) + @as(usize, spacing) + (@as(usize, surf1.size.width) / 2) - (@as(usize, box1.size.width) / 2));
            player_label_sub = vxfw.SubSurface{ .origin = .{ .row = box_row, .col = box0_col }, .surface = box0 };
            // place the second box as a separate child slot (we'll add it below)
            player_label_sub_1 = vxfw.SubSurface{ .origin = .{ .row = box_row, .col = box1_col }, .surface = box1 };
        }

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
        // Build children list. Order:
        // dealer label, dealer hand,
        // player label, player hand[, second hand, bets..., active indicator],
        // status, [buttons...]
        var hit_sub: vxfw.SubSurface = undefined;
        var stand_sub: vxfw.SubSurface = undefined;
        var double_sub: vxfw.SubSurface = undefined;
        var split_col: u16 = 0;

        var count: usize = 0;
        // dealer label + dealer hand
        count += 2;
        // player area: different number of children depending on single/split
        if (game.player.hand_count > 1) {
            // two-hand layout: two label boxes + two hand surfaces + two bets + active slot
            count += 7; // player_label_sub, player_label_sub_1, player_sub, player_sub_1, bet0, bet1, active_slot
        } else {
            // single-hand layout: one label box + one hand surface
            count += 2; // player_label_sub, player_sub
        }
        // status
        count += 1;

        if (game.phase == .player_turn) {
            const hit_surf = try self.hit_btn.draw(ctx);
            const stand_surf = try self.stand_btn.draw(ctx);
            const double_surf = try self.double_btn.draw(ctx);
            // Decide if split is allowed: only when player has a single hand,
            // exactly two cards of same rank, and player can afford matching bet.
            var split_allowed: bool = false;
            if (game.player.hand_count == 1) {
                const h = game.player.hands[0];
                if (h.count == 2) {
                    const c0 = h.cards[0];
                    const c1 = h.cards[1];
                    if (c0.rank == c1.rank and game.player.bankroll >= game.player.bets[0]) {
                        split_allowed = true;
                    }
                }
            }

            self.split_btn.enabled = split_allowed;
            // split_sub removed; draw inline when appending children

            const base_row = player_y + player_surf_height + 2;
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

            split_col = @intCast((if (@as(usize, mid) + 40 < @as(usize, size.width)) @as(usize, mid) + 40 else @as(usize, mid)));
            // 4 button children (hit/stand/double/split)
            count += 4;
        }
        const empty_text = vxfw.Text{ .text = try std.fmt.allocPrint(ctx.arena, "", .{}) };
        const empty_surf = try empty_text.draw(ctx);
        const children = try ctx.arena.alloc(vxfw.SubSurface, count);
        var ci: usize = 0;
        children[ci] = dealer_label_sub;
        ci += 1;
        children[ci] = dealer_sub;
        ci += 1;
        if (game.player.hand_count > 1) {
            // two-hand layout: show both hand boxes, then both hands and bets
            children[ci] = player_label_sub;
            ci += 1;
            children[ci] = player_label_sub_1;
            ci += 1;
            children[ci] = player_sub;
            ci += 1;
            children[ci] = player_sub_1;
            ci += 1;
            children[ci] = bet_sub_0;
            ci += 1;
            children[ci] = bet_sub_1;
            ci += 1;
            // active_sub may be undefined when blink is off; only add if set
            if (active_present) {
                children[ci] = active_sub;
                ci += 1;
            } else {
                // reserved slot consumed even if not visible: provide empty subsurface
                children[ci] = .{ .origin = .{ .row = 0, .col = 0 }, .surface = empty_surf };
                ci += 1;
            }
        } else {
            // single-hand layout
            children[ci] = player_label_sub;
            ci += 1;
            children[ci] = player_sub;
            ci += 1;
        }
        children[ci] = status_sub;
        ci += 1;

        if (game.phase == .player_turn) {
            // append buttons after existing children
            children[ci] = hit_sub;
            ci += 1;
            children[ci] = stand_sub;
            ci += 1;
            children[ci] = double_sub;
            ci += 1;
            children[ci] = .{ .origin = .{ .row = hit_sub.origin.row, .col = split_col }, .surface = try self.split_btn.draw(ctx) };
        }

        // Debug: report any out-of-bounds child origins before clamping.
        // debug messages removed

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
