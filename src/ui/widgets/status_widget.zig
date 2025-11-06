const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub const StatusWidget = struct {
    message: []const u8 = "",

    pub fn init() StatusWidget {
        return .{ .message = "" };
    }

    pub fn setMessage(self: *StatusWidget, msg: []const u8) void {
        self.message = msg;
    }

    pub fn widget(self: *StatusWidget) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = StatusWidget.onEvent,
            .drawFn = StatusWidget.onDraw,
        };
    }

    fn onEvent(_: *anyopaque, _: *vxfw.EventContext, _: vxfw.Event) anyerror!void {
        // Status bar does not consume or respond to events
        return;
    }

    fn onDraw(ptr: *anyopaque, ctx: vxfw.DrawContext) !vxfw.Surface {
        const self: *StatusWidget = @ptrCast(@alignCast(ptr));
        const size = ctx.max.size();
        const arena = ctx.arena;

        const msg = if (self.message.len == 0) "" else self.message;

        // Render text using Vaxis's built-in Text widget
        const text_widget = vxfw.Text{ .text = msg };
        const text_surface = try text_widget.draw(ctx);

        const row = size.height / 2;
        const col = (size.width / 2) - (text_surface.size.width / 2);

        const children = try arena.alloc(vxfw.SubSurface, 1);
        children[0] = .{
            .origin = .{ .row = row, .col = col },
            .surface = text_surface,
        };

        return .{
            .size = size,
            .widget = self.widget(),
            .buffer = &.{}, // always empty for custom widgets in 0.5.x
            .children = children,
        };
    }
};
