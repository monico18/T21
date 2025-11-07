const std = @import("std");
const vaxis = @import("vaxis");
const isEmpty = @import("../../key_util.zig").modsEmpty;
const vxfw = vaxis.vxfw;

const Model = @import("../model.zig").Model;
const ButtonWidget = @import("../widgets/button_widget.zig").ButtonWidget;

pub const MenuScreen = struct {
    selected: usize = 0,

    play_btn: ButtonWidget,
    save_btn: ButtonWidget,
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

        // --- Save & Quit callback -------------------------------------------
        const onSave = struct {
            fn cb(userdata: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
                const m: *Model = @ptrCast(@alignCast(userdata.?));
                // Persist bankroll to a local file and then quit.
                try m.game.saveBankroll("bankroll.bin");
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
            .save_btn = .{ .label = "Save & Quit", .onClick = onSave, .userdata = model },
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
                    if (self.selected < 2) self.selected += 1;
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
            2 => try ctx.requestFocus(self.quit_btn.widget()),
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
        const quit_surf = try self.quit_btn.draw(ctx);

        const y_title = size.height / 4;
        const y_play = size.height / 2 - 1;
        const y_save = y_play + play_surf.size.height + 1;
        const y_quit = y_save + save_surf.size.height + 1;

        const children = try ctx.arena.alloc(vxfw.SubSurface, 4);

        children[0] = .{
            .origin = .{ .row = y_title, .col = mid - (title_surf.size.width / 2) },
            .surface = title_surf,
        };

        children[1] = .{
            .origin = .{ .row = y_play, .col = mid - (play_surf.size.width / 2) },
            .surface = play_surf,
        };

        children[2] = .{
            .origin = .{ .row = y_save, .col = mid - (save_surf.size.width / 2) },
            .surface = save_surf,
        };

        children[3] = .{
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
