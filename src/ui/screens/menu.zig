const std = @import("std");
const vaxis = @import("vaxis");
const isEmpty = @import("../../key_util.zig").modsEmpty;
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

pub const MenuScreen = struct {
    selected: usize = 0,

    play_btn: ButtonWidget,
    quit_btn: ButtonWidget,

    pub fn init(model: *Model) MenuScreen {

        // --- Play callback -------------------------------------------------
        const onPlay = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const m: *Model = @ptrCast(@alignCast(userdata.?));
                m.current_screen = .betting;
                std.debug.print("[menu] Play callback invoked\n", .{});
                _ = ctx.consumeAndRedraw();
            }
        }.cb;

        // --- Quit callback -------------------------------------------------
        const onQuit = struct {
            fn cb(_: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                std.debug.print("[menu] Quit callback invoked\n", .{});
                ctx.quit = true;
            }
        }.cb;

        return MenuScreen{
            .selected = 0,
            .play_btn = .{ .label = "Play", .onClick = onPlay, .userdata = model },
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
                    if (self.selected < 1) self.selected += 1;
                    try self.updateFocus(ctx);
                    return ctx.consumeAndRedraw();
                }
            },

            else => {},
        }
    }

    fn updateFocus(self: *MenuScreen, ctx: *vxfw.EventContext) !void {
        switch (self.selected) {
            0 => {
                std.debug.print("[menu] updateFocus: requesting focus on play_btn\n", .{});
                try ctx.requestFocus(self.play_btn.widget());
            },
            1 => {
                std.debug.print("[menu] updateFocus: requesting focus on quit_btn\n", .{});
                try ctx.requestFocus(self.quit_btn.widget());
            },
            else => {},
        }
    }

    pub fn draw(self: *MenuScreen, model: *Model, ctx: vxfw.DrawContext) !vxfw.Surface {
        const size = ctx.max.size();
        const mid = size.width / 2;

        const title = vxfw.Text{ .text = "BLACKJACK" };
        const title_surf = try title.draw(ctx);

        const play_surf = try self.play_btn.draw(ctx);
        const quit_surf = try self.quit_btn.draw(ctx);

        const y_title = size.height / 4;
        const y_play = size.height / 2 - 1;
        const y_quit = y_play + play_surf.size.height + 2;

        const children = try ctx.arena.alloc(vxfw.SubSurface, 3);

        children[0] = .{
            .origin = .{ .row = y_title, .col = mid - (title_surf.size.width / 2) },
            .surface = title_surf,
        };

        children[1] = .{
            .origin = .{ .row = y_play, .col = mid - (play_surf.size.width / 2) },
            .surface = play_surf,
        };

        children[2] = .{
            .origin = .{ .row = y_quit, .col = mid - (quit_surf.size.width / 2) },
            .surface = quit_surf,
        };

        var _empty_menu_cells: [0]vaxis.Cell = .{};

        return .{
            .size = size,
            .widget = model.widget(),
            .buffer = &_empty_menu_cells,
            .children = children,
        };
    }
};
