const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub const ButtonWidget = struct {
    label: []const u8,
    onClick: *const fn (?*anyopaque, *vxfw.EventContext) anyerror!void,
    userdata: ?*anyopaque = null,

    pub fn draw(self: *ButtonWidget, ctx: vxfw.DrawContext) !vxfw.Surface {
        return onDraw(self, ctx);
    }

    pub fn widget(self: *ButtonWidget) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = onEvent,
            .drawFn = drawFnWrapper,
        };
    }

    fn drawFnWrapper(ptr: *anyopaque, ctx: vxfw.DrawContext) !vxfw.Surface {
        const self: *ButtonWidget = @ptrCast(@alignCast(ptr));
        return onDraw(self, ctx);
    }

    fn onEvent(ptr: *anyopaque, ctx: *vxfw.EventContext, ev: vxfw.Event) anyerror!void {
        const self: *ButtonWidget = @ptrCast(@alignCast(ptr));

        // Only trigger the button on mouse press/click. Do NOT trigger on
        // Enter key presses — we want mouse-only activation per project spec.
        switch (ev) {
            // Try mouse press/click event name used by vxfw.
            .mouse => |m| {
                // Only activate on left-button press (actual click), not on motion/enter.
                if (m.type == vaxis.Mouse.Type.press and m.button == vaxis.Mouse.Button.left) {
                    return self.onClick(self.userdata, ctx);
                }
            },
            .focus_in => {
                // when focused, we don't activate on Enter; keep focus behavior only
                return;
            },
            else => {},
        }
    }

    fn onDraw(self: *ButtonWidget, ctx: vxfw.DrawContext) !vxfw.Surface {
        const padding: i17 = 2;
        const w: i17 = @as(i17, @intCast(self.label.len)) + padding * 2;
        const h: i17 = 3;

        const usize_w = @as(usize, @intCast(w));
        const usize_h = @as(usize, @intCast(h));

        const arena = ctx.arena;
        const buffer = try arena.alloc(vaxis.Cell, usize_w * usize_h);

        // fill background
        for (buffer) |*c| {
            c.char = .{ .grapheme = " ", .width = 1 };
            c.style = .{};
            c.link = .{};
            c.image = null;
            c.default = false;
            c.wrapped = false;
            c.scale = .{};
        }

        drawBox(buffer, usize_w, usize_h);

        // centered text
        const text_col: i17 = @divTrunc((w - @as(i17, @intCast(self.label.len))), @as(i17, 2));
        const text_row: i17 = 1;

        var i: usize = 0;
        while (i < self.label.len) : (i += 1) {
            const col = @as(usize, @intCast(text_col + @as(i17, @intCast(i))));
            const row = @as(usize, @intCast(text_row));
            buffer[row * usize_w + col].char.grapheme = self.label[i .. i + 1];
        }

        return .{
            .size = .{ .width = @intCast(w), .height = @intCast(h) },
            .widget = self.widget(),
            .buffer = buffer,
            .children = &_empty_button_children,
        };
    }
};

// Typed zero-length children for ButtonWidget to avoid returning the
// address of a temporary stack literal (&{}), which becomes invalid
// after the draw function returns and can cause crashes during layout
// or event handling.
var _empty_button_children: [0]vxfw.SubSurface = .{};

fn drawBox(buf: []vaxis.Cell, w: usize, h: usize) void {
    buf[0].char.grapheme = "┌";
    buf[w - 1].char.grapheme = "┐";
    buf[(h - 1) * w].char.grapheme = "└";
    buf[(h - 1) * w + (w - 1)].char.grapheme = "┘";

    // horizontal
    var x: usize = 1;
    while (x < w - 1) : (x += 1) {
        buf[x].char.grapheme = "─";
        buf[(h - 1) * w + x].char.grapheme = "─";
    }

    // vertical
    var y: usize = 1;
    while (y < h - 1) : (y += 1) {
        buf[y * w].char.grapheme = "│";
        buf[y * w + (w - 1)].char.grapheme = "│";
    }
}
