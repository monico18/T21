const std = @import("std");
const vaxis = @import("vaxis");
const isEmpty = @import("../../key_util.zig").modsEmpty;
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

// Safe centering helper: returns a signed column suitable for SubSurface.origin
fn center_col(mid: u16, inner_w: u16) i17 {
    const mid_us = @as(usize, mid);
    const half = @as(usize, inner_w) / 2;
    const col_us = if (mid_us > half) mid_us - half else 0;
    return @intCast(col_us);
}

pub const MenuScreen = struct {
    selected: usize = 0,

    play_btn: ButtonWidget,
    save_btn: ButtonWidget,
    save_quit_btn: ButtonWidget,
    quit_btn: ButtonWidget,

    pub fn init(model: *Model) MenuScreen {

        // --- Play callback -------------------------------------------------
        const onPlay = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const m: *Model = @ptrCast(@alignCast(userdata.?));
                m.current_screen = .betting;
                //std.debug.print("[menu] Play callback invoked\n", .{});
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // --- Save (no quit) callback ----------------------------------------
        const onSaveOnly = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const m: *Model = @ptrCast(@alignCast(userdata.?));
                try m.game.saveBankrollDefault();
                // show a simple status message
                m.status.setMessage("Saved.");
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // --- Save & Quit callback -------------------------------------------
        const onSaveAndQuit = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const m: *Model = @ptrCast(@alignCast(userdata.?));
                try m.game.saveBankrollDefault();
                ctx.quit = true;
            }
        }.cb;

        // --- Quit callback -------------------------------------------------
        const onQuit = struct {
            fn cb(_: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                ctx.quit = true;
            }
        }.cb;

        return MenuScreen{
            .selected = 0,
            .play_btn = .{ .label = "Play", .onClick = onPlay, .userdata = model },
            .save_btn = .{ .label = "Save", .onClick = onSaveOnly, .userdata = model },
            .save_quit_btn = .{ .label = "Save & Quit", .onClick = onSaveAndQuit, .userdata = model },
            .quit_btn = .{ .label = "Quit", .onClick = onQuit, .userdata = null },
        };
    }

    pub fn handleEvent(
        self: *MenuScreen,
        _: *Model,
        ctx: *vxfw.EventContext,
        event: vxfw.Event,
    ) !void {
        switch (event) {
            .init => {
                // Intentionally not requesting focus here to avoid focus-path
                // assertion in vxfw when the widget tree isn't fully installed
                // yet. Focus will be set by user navigation or explicit
                // updateFocus calls.
            },

            .key_press => |key| {
                // quit keys
                if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                    ctx.quit = true;
                    return;
                }

                // --- navigation: UP -------------------------------------------------
                if (key.matches(vaxis.Key.up, .{}) and isEmpty(key.mods)) {
                    if (self.selected > 0) self.selected -= 1;
                    try self.updateFocus(ctx);
                    return ctx.consumeAndRedraw();
                }

                // --- navigation: DOWN -----------------------------------------------
                if (key.matches(vaxis.Key.down, .{}) and isEmpty(key.mods)) {
                    if (self.selected < 3) self.selected += 1;
                    try self.updateFocus(ctx);
                    return ctx.consumeAndRedraw();
                }
            },

            else => {},
        }
    }

    fn updateFocus(self: *MenuScreen, ctx: *vxfw.EventContext) !void {
        switch (self.selected) {
            0 => try ctx.requestFocus(self.play_btn.widget()),
            1 => try ctx.requestFocus(self.save_btn.widget()),
            2 => try ctx.requestFocus(self.save_quit_btn.widget()),
            3 => try ctx.requestFocus(self.quit_btn.widget()),
            else => {},
        }
    }

    pub fn draw(self: *MenuScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const mid = size.width / 2;

        const title = vxfw.Text{ .text = "BLACKJACK" };
        const title_surf = try title.draw(ctx);

        const play_surf = try self.play_btn.draw(ctx);
        const save_surf = try self.save_btn.draw(ctx);
        const save_quit_surf = try self.save_quit_btn.draw(ctx);
        const quit_surf = try self.quit_btn.draw(ctx);

        const y_title = size.height / 4;
        // Guard subtraction to avoid unsigned underflow on tiny heights.
        const y_play: u16 = if (size.height > 1) size.height / 2 - 1 else 0;
        const y_save = y_play + play_surf.size.height + 1;
        const y_save_quit = y_save + save_surf.size.height + 1;
        const y_quit = y_save_quit + save_quit_surf.size.height + 1;

        const children = try ctx.arena.alloc(vxfw.SubSurface, 5);

        children[0] = .{ .origin = .{ .row = y_title, .col = center_col(mid, @as(u16, title_surf.size.width)) }, .surface = title_surf };
        children[1] = .{ .origin = .{ .row = y_play, .col = center_col(mid, @as(u16, play_surf.size.width)) }, .surface = play_surf };
        children[2] = .{ .origin = .{ .row = y_save, .col = center_col(mid, @as(u16, save_surf.size.width)) }, .surface = save_surf };
        children[3] = .{ .origin = .{ .row = y_save_quit, .col = center_col(mid, @as(u16, save_quit_surf.size.width)) }, .surface = save_quit_surf };
        children[4] = .{ .origin = .{ .row = y_quit, .col = center_col(mid, @as(u16, quit_surf.size.width)) }, .surface = quit_surf };

        // Debug print any out-of-bounds origins before clamping.
        // debug messages removed

        // Clamp origins to avoid unsigned underflow when vaxis computes
        // child regions.
        const max_row: u16 = if (size.height > 0) size.height - 1 else 0;
        const max_col: u16 = if (size.width > 0) size.width - 1 else 0;
        for (children) |*c| {
            if (c.origin.row > max_row) c.origin.row = max_row;
            if (c.origin.col > max_col) c.origin.col = max_col;
        }

        var _empty_menu_cells: [0]vaxis.Cell = .{};

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &_empty_menu_cells,
            .children = children,
        };
    }
};
