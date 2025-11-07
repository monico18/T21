const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const ui_style = @import("../style.zig");
const GameState = @import("../../game/state.zig").GameState;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

// Safe centering helper: returns a signed column suitable for SubSurface.origin
fn center_col(mid: u16, inner_w: u16) i17 {
    const mid_us = @as(usize, mid);
    const half = @as(usize, inner_w) / 2;
    const col_us = if (mid_us > half) mid_us - half else 0;
    return @intCast(col_us);
}

pub const BettingScreen = struct {
    game: *GameState,
    model: *Model,

    bet: i32 = 10,

    plus_btn: ButtonWidget,
    plus25_btn: ButtonWidget,
    plus10_btn: ButtonWidget,
    plus50_btn: ButtonWidget,
    plus100_btn: ButtonWidget,
    minus_btn: ButtonWidget,
    minus25_btn: ButtonWidget,
    minus10_btn: ButtonWidget,
    minus50_btn: ButtonWidget,
    minus100_btn: ButtonWidget,
    all_in_btn: ButtonWidget,
    clear_btn: ButtonWidget,
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
                // Allow decrement to reach 0 (user requested).
                if (self.bet > 0) self.bet -= 1;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // +25 button
        const onPlus25 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet += 25;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // -25 button
        const onMinus25 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                if (self.bet > 25) {
                    self.bet -= 25;
                } else {
                    self.bet = 0;
                }
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // -50 button
        const onMinus50 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                if (self.bet > 50) {
                    self.bet -= 50;
                } else {
                    self.bet = 0;
                }
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // -100 button
        const onMinus100 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                if (self.bet > 100) {
                    self.bet -= 100;
                } else {
                    self.bet = 0;
                }
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // Clear bet
        const onClear = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet = 0;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // +50 button
        const onPlus50 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet += 50;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // +100 button
        const onPlus100 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet += 100;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // All-in button
        // +10 button
        const onPlus10 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet += 10;
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // -10 button
        const onMinus10 = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                if (self.bet > 10) {
                    self.bet -= 10;
                } else {
                    self.bet = 0; // allow zero
                }
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        const onAllIn = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const self: *BettingScreen = @ptrCast(@alignCast(userdata.?));
                self.bet = self.game.player.bankroll;
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
        // Chip colors for denominations. Create reusable style constants
        // first to keep the initializer readable.
        return BettingScreen{
            .game = game,
            .model = model,
            .bet = 10,

            .plus_btn = .{ .label = "+", .onClick = onPlus, .userdata = null, .borderless = true, .style = ui_style.chip_white, .focused_style = ui_style.chip_white_focus },
            .plus25_btn = .{ .label = "+", .onClick = onPlus25, .userdata = null, .borderless = true, .style = ui_style.chip_red, .focused_style = ui_style.chip_red_focus },
            .plus10_btn = .{ .label = "+", .onClick = onPlus10, .userdata = null, .borderless = true, .style = ui_style.chip_blue, .focused_style = ui_style.chip_blue_focus },
            .plus50_btn = .{ .label = "+", .onClick = onPlus50, .userdata = null, .borderless = true, .style = ui_style.chip_green, .focused_style = ui_style.chip_green_focus },
            .plus100_btn = .{ .label = "+", .onClick = onPlus100, .userdata = null, .borderless = true, .style = ui_style.chip_gold, .focused_style = ui_style.chip_gold_focus },
            .minus_btn = .{ .label = "-", .onClick = onMinus, .userdata = null, .borderless = true, .style = ui_style.chip_white, .focused_style = ui_style.chip_white_focus },
            .minus25_btn = .{ .label = "-", .onClick = onMinus25, .userdata = null, .borderless = true, .style = ui_style.chip_red, .focused_style = ui_style.chip_red_focus },
            .minus10_btn = .{ .label = "-", .onClick = onMinus10, .userdata = null, .borderless = true, .style = ui_style.chip_blue, .focused_style = ui_style.chip_blue_focus },
            .minus50_btn = .{ .label = "-", .onClick = onMinus50, .userdata = null, .borderless = true, .style = ui_style.chip_green, .focused_style = ui_style.chip_green_focus },
            .minus100_btn = .{ .label = "-", .onClick = onMinus100, .userdata = null, .borderless = true, .style = ui_style.chip_gold, .focused_style = ui_style.chip_gold_focus },
            .all_in_btn = .{ .label = "All In", .onClick = onAllIn, .userdata = null },
            .clear_btn = .{ .label = "Clear", .onClick = onClear, .userdata = null },
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
                    if (self.selected < 11) self.selected += 1;
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
            0 => try ctx.requestFocus(self.plus_btn.widget()),
            1 => try ctx.requestFocus(self.plus25_btn.widget()),
            2 => try ctx.requestFocus(self.plus50_btn.widget()),
            3 => try ctx.requestFocus(self.plus100_btn.widget()),
            4 => try ctx.requestFocus(self.minus_btn.widget()),
            5 => try ctx.requestFocus(self.minus25_btn.widget()),
            6 => try ctx.requestFocus(self.minus50_btn.widget()),
            7 => try ctx.requestFocus(self.minus100_btn.widget()),
            8 => try ctx.requestFocus(self.all_in_btn.widget()),
            9 => try ctx.requestFocus(self.clear_btn.widget()),
            10 => {
                // Confirm: only focusable if bet > 0
                if (self.bet > 0) {
                    try ctx.requestFocus(self.confirm_btn.widget());
                } else {
                    // skip to back if confirm should be disabled
                    try ctx.requestFocus(self.back_btn.widget());
                }
            },
            11 => try ctx.requestFocus(self.back_btn.widget()),
            else => {},
        }
    }

    pub fn draw(self: *BettingScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const mid = size.width / 2;

        const title = vxfw.Text{ .text = "PLACE YOUR BET" };
        const bank = vxfw.Text{ .text = try std.fmt.allocPrint(ctx.arena, "Bankroll: {d}", .{self.game.player.bankroll}) };
        const bet = vxfw.Text{ .text = try std.fmt.allocPrint(ctx.arena, "Bet:      {d}", .{self.bet}) };

        const t_surf = try title.draw(ctx);
        const b_surf = try bank.draw(ctx);
        const bet_surf = try bet.draw(ctx);

        const plus_surf = try self.plus_btn.draw(ctx);
        const plus10_surf = try self.plus10_btn.draw(ctx);
        const plus25_surf = try self.plus25_btn.draw(ctx);
        const plus50_surf = try self.plus50_btn.draw(ctx);
        const plus100_surf = try self.plus100_btn.draw(ctx);
        const minus_surf = try self.minus_btn.draw(ctx);
        const minus10_surf = try self.minus10_btn.draw(ctx);
        const minus25_surf = try self.minus25_btn.draw(ctx);
        const minus50_surf = try self.minus50_btn.draw(ctx);
        const minus100_surf = try self.minus100_btn.draw(ctx);
        const all_in_surf = try self.all_in_btn.draw(ctx);
        const clear_surf = try self.clear_btn.draw(ctx);

        const y_title = size.height / 8;
        const y_bank = y_title + 2;
        const y_bet = y_bank + 2;

        const groups_count: usize = 5; // 1,10,25,50,100
        const gap: usize = 4;

        const val1_text = try std.fmt.allocPrint(ctx.arena, "1", .{});
        const val10_text = try std.fmt.allocPrint(ctx.arena, "10", .{});
        const val25_text = try std.fmt.allocPrint(ctx.arena, "25", .{});
        const val50_text = try std.fmt.allocPrint(ctx.arena, "50", .{});
        const val100_text = try std.fmt.allocPrint(ctx.arena, "100", .{});

        const val1_surf = try (vxfw.Text{ .text = val1_text, .style = ui_style.chip_white }).draw(ctx);
        const val10_surf = try (vxfw.Text{ .text = val10_text, .style = ui_style.chip_blue }).draw(ctx);
        const val25_surf = try (vxfw.Text{ .text = val25_text, .style = ui_style.chip_red }).draw(ctx);
        const val50_surf = try (vxfw.Text{ .text = val50_text, .style = ui_style.chip_green }).draw(ctx);
        const val100_surf = try (vxfw.Text{ .text = val100_text, .style = ui_style.chip_gold }).draw(ctx);

        const g0_top = plus_surf;
        const g0_mid = val1_surf;
        const g0_bot = minus_surf;
        const g1_top = plus10_surf;
        const g1_mid = val10_surf;
        const g1_bot = minus10_surf;
        const g2_top = plus25_surf;
        const g2_mid = val25_surf;
        const g2_bot = minus25_surf;
        const g3_top = plus50_surf;
        const g3_mid = val50_surf;
        const g3_bot = minus50_surf;
        const g4_top = plus100_surf;
        const g4_mid = val100_surf;
        const g4_bot = minus100_surf;

        const extra1 = all_in_surf;
        const extra2 = clear_surf;

        // widths per group (max of three rows)
        const gw0: usize = if (g0_top.size.width > g0_mid.size.width) (if (g0_top.size.width > g0_bot.size.width) g0_top.size.width else g0_bot.size.width) else (if (g0_mid.size.width > g0_bot.size.width) g0_mid.size.width else g0_bot.size.width);
        const gw1: usize = if (g1_top.size.width > g1_mid.size.width) (if (g1_top.size.width > g1_bot.size.width) g1_top.size.width else g1_bot.size.width) else (if (g1_mid.size.width > g1_bot.size.width) g1_mid.size.width else g1_bot.size.width);
        const gw2: usize = if (g2_top.size.width > g2_mid.size.width) (if (g2_top.size.width > g2_bot.size.width) g2_top.size.width else g2_bot.size.width) else (if (g2_mid.size.width > g2_bot.size.width) g2_mid.size.width else g2_bot.size.width);
        const gw3: usize = if (g3_top.size.width > g3_mid.size.width) (if (g3_top.size.width > g3_bot.size.width) g3_top.size.width else g3_bot.size.width) else (if (g3_mid.size.width > g3_bot.size.width) g3_mid.size.width else g3_bot.size.width);
        const gw4: usize = if (g4_top.size.width > g4_mid.size.width) (if (g4_top.size.width > g4_bot.size.width) g4_top.size.width else g4_bot.size.width) else (if (g4_mid.size.width > g4_bot.size.width) g4_mid.size.width else g4_bot.size.width);

        const extras_w: usize = extra1.size.width + extra2.size.width + gap;
        const total_width: usize = gw0 + gw1 + gw2 + gw3 + gw4 + gap * (groups_count - 1) + extras_w;
        const start_col: usize = if (total_width > @as(usize, mid)) 0 else @as(usize, mid) - (total_width / 2);

        const height_usize: usize = @as(usize, size.height);
        const top_row: usize = if (height_usize > 12) (height_usize / 2 - 6) else 0;
        const mid_row: usize = top_row + @as(usize, g0_top.size.height) + 1;
        const bot_row: usize = mid_row + @as(usize, g0_mid.size.height) + 1;

        const child_count: usize = 3 + groups_count + 2 + 2; // title/bank/bet + groups + extras + confirm/back
        const children = try ctx.arena.alloc(vxfw.SubSurface, child_count);
        children[0] = .{ .origin = .{ .row = y_title, .col = center_col(mid, @intCast(t_surf.size.width)) }, .surface = t_surf };
        children[1] = .{ .origin = .{ .row = y_bank, .col = center_col(mid, @intCast(b_surf.size.width)) }, .surface = b_surf };
        children[2] = .{ .origin = .{ .row = y_bet, .col = center_col(mid, @intCast(bet_surf.size.width)) }, .surface = bet_surf };

        var cur_col: usize = start_col;

        const tops: [5]vxfw.Surface = .{ g0_top, g1_top, g2_top, g3_top, g4_top };
        const mids: [5]vxfw.Surface = .{ g0_mid, g1_mid, g2_mid, g3_mid, g4_mid };
        const bots: [5]vxfw.Surface = .{ g0_bot, g1_bot, g2_bot, g3_bot, g4_bot };
        const gws: [5]usize = .{ gw0, gw1, gw2, gw3, gw4 };

        var out_child_idx: usize = 3;
        var gi: usize = 0;
        while (gi < groups_count) : (gi += 1) {
            const inner_w = gws[gi];
            const top_h = tops[gi].size.height;
            const mid_h = mids[gi].size.height;
            const bot_h = bots[gi].size.height;

            const outer_w: usize = inner_w + 4; // padding left/right
            const outer_h: usize = top_h + mid_h + bot_h + 4; // borders + gaps

            const outer_buf = try ctx.arena.alloc(vaxis.Cell, outer_w * outer_h);
            for (outer_buf) |*c| {
                c.char = .{ .grapheme = " ", .width = 1 };
                c.style = .{};
                c.link = .{};
                c.image = null;
                c.default = false;
                c.wrapped = false;
                c.scale = .{};
            }
            drawBoxInto(outer_buf, outer_w, outer_h);

            const inner_children = try ctx.arena.alloc(vxfw.SubSurface, 3);
            const top_col: usize = (outer_w - tops[gi].size.width) / 2;
            const mid_col: usize = (outer_w - mids[gi].size.width) / 2;
            const bot_col: usize = (outer_w - bots[gi].size.width) / 2;

            const top_row_in: usize = 1;
            const mid_row_in: usize = top_row_in + top_h + 1;
            const bot_row_in: usize = mid_row_in + mid_h + 1;

            inner_children[0] = .{ .origin = .{ .row = @intCast(top_row_in), .col = @intCast(top_col) }, .surface = tops[gi] };
            inner_children[1] = .{ .origin = .{ .row = @intCast(mid_row_in), .col = @intCast(mid_col) }, .surface = mids[gi] };
            inner_children[2] = .{ .origin = .{ .row = @intCast(bot_row_in), .col = @intCast(bot_col) }, .surface = bots[gi] };

            const outer_surf: vxfw.Surface = .{
                .size = .{ .width = @intCast(outer_w), .height = @intCast(outer_h) },
                .widget = .{ .userdata = @ptrCast(&nonInteractiveSentinel_bet), .eventHandler = null, .drawFn = nonInteractiveBetDraw },
                .buffer = outer_buf,
                .children = inner_children,
            };

            children[out_child_idx] = .{ .origin = .{ .row = @intCast(top_row), .col = @intCast(cur_col) }, .surface = outer_surf };
            out_child_idx += 1;
            cur_col += outer_w + gap;
        }

        // place extras centered around mid, but put them above the + buttons
        const mid_us = @as(usize, mid);
        const extras_half = extras_w / 2;
        const left_anchor_us = if (mid_us > extras_half) mid_us - extras_half else 0;
        const right_anchor_us = mid_us + extras_half;
        const left_anchor: u16 = @intCast(left_anchor_us);
        const right_anchor: u16 = @intCast(right_anchor_us);

        // compute extras row so they appear above the + buttons (groups' top)
        const max_extra_h: usize = if (extra1.size.height > extra2.size.height) @as(usize, extra1.size.height) else @as(usize, extra2.size.height);
        const extras_row_us: usize = if (top_row > (max_extra_h + 1)) top_row - (max_extra_h + 1) else 0;
        const extras_row: u16 = @intCast(extras_row_us);

        children[out_child_idx] = .{ .origin = .{ .row = extras_row, .col = center_col(left_anchor, @intCast(extra1.size.width)) }, .surface = extra1 };
        out_child_idx += 1;
        children[out_child_idx] = .{ .origin = .{ .row = extras_row, .col = center_col(right_anchor, @intCast(extra2.size.width)) }, .surface = extra2 };
        out_child_idx += 1;

        self.confirm_btn.enabled = (self.bet > 0);
        const confirm_surf = try self.confirm_btn.draw(ctx);
        const back_surf = try self.back_btn.draw(ctx);

        children[out_child_idx] = .{ .origin = .{ .row = @intCast(bot_row + 8), .col = center_col(mid, @intCast(confirm_surf.size.width)) }, .surface = confirm_surf };
        out_child_idx += 1;
        children[out_child_idx] = .{ .origin = .{ .row = @intCast(bot_row + 8 + confirm_surf.size.height + 2), .col = center_col(mid, @intCast(back_surf.size.width)) }, .surface = back_surf };

        // Debug and clamp
        // debug messages removed

        const max_row: u16 = if (size.height > 0) size.height - 1 else 0;
        const max_col: u16 = if (size.width > 0) size.width - 1 else 0;
        for (children) |*c| {
            if (c.origin.row > max_row) c.origin.row = max_row;
            if (c.origin.col > max_col) c.origin.col = max_col;
        }

        var _empty_betting_cells: [0]vaxis.Cell = .{};

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &_empty_betting_cells,
            .children = children,
        };
    }
};

// File-scope helper: draw box glyphs into a cell buffer.
fn drawBoxInto(buf: []vaxis.Cell, w: usize, h: usize) void {
    if (w == 0 or h == 0) return;
    buf[0].char.grapheme = "┌";
    buf[w - 1].char.grapheme = "┐";
    buf[(h - 1) * w].char.grapheme = "└";
    buf[(h - 1) * w + (w - 1)].char.grapheme = "┘";

    var x: usize = 1;
    while (x < w - 1) : (x += 1) {
        buf[x].char.grapheme = "─";
        buf[(h - 1) * w + x].char.grapheme = "─";
    }

    var y: usize = 1;
    while (y < h - 1) : (y += 1) {
        buf[y * w].char.grapheme = "│";
        buf[y * w + (w - 1)].char.grapheme = "│";
    }
}

// Non-interactive sentinel for temporary betting surfaces
var nonInteractiveSentinel_bet: u8 = 0;

fn nonInteractiveBetDraw(ptr: *anyopaque, ctx: vxfw.DrawContext) error{OutOfMemory}!vxfw.Surface {
    _ = ptr;
    _ = ctx;
    return .{
        .size = .{ .width = 0, .height = 0 },
        .widget = .{
            .userdata = @ptrCast(&nonInteractiveSentinel_bet),
            .eventHandler = null,
            .drawFn = nonInteractiveBetDraw,
        },
        .buffer = &_bet_nonint_cells,
        .children = &_bet_nonint_children,
    };
}

var _bet_nonint_cells: [0]vaxis.Cell = .{};
var _bet_nonint_children: [0]vxfw.SubSurface = .{};
