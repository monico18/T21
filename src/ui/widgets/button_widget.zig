const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub const ButtonWidget = struct {
    label: []const u8,
    onClick: *const fn (?*anyopaque, *vxfw.EventContext) anyerror!void,
    userdata: ?*anyopaque = null,
    // when false, the button renders in a "disabled" style and will not
    // invoke the onClick callback.
    enabled: bool = true,
    // When true the widget will render only the label text without the
    // surrounding box. This is useful when the caller wants to compose
    // a custom surrounding frame and keep the button interactive.
    borderless: bool = false,
    // Optional style applied to all cells in the button. Allows callers to
    // color the button background/foreground (e.g., emulate casino chips).
    style: vaxis.Style = .{},
    // Optional style applied when the widget is focused/hovered. Fields set
    // here will override the base `style` when focused. Provide a
    // reasonable default so all buttons gain a visible highlight without
    // requiring callers to wire focused_style manually.
    focused_style: vaxis.Style = vaxis.Style{ .reverse = true, .bold = true },

    // Internal: whether the widget is currently focused/hovered. Updated
    // via focus_in/focus_out and mouse_enter/mouse_leave events so the
    // draw function can show a hover/focus state.
    focused: bool = false,
    // Internal: whether the widget is being 'entered' via keyboard (Enter
    // key). When true the draw function will show a checkered activation
    // background. This is intentionally separate from `focused` so we can
    // show a transient pressed/entered visual without changing focus.
    entered: bool = false,

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
                    if (!self.enabled) return;
                    return self.onClick(self.userdata, ctx);
                }
            },
            // Track focus and hover so draw() can show a highlighted state
            .focus_in => {
                self.focused = true;
                return;
            },
            .focus_out => {
                self.focused = false;
                // clear any transient entered state when focus is lost
                self.entered = false;
                return;
            },
            .mouse_enter => {
                // Only set the widget-local focused flag on mouse enter.
                // Requesting framework focus here can trigger internal
                // assertions when the widget isn't yet present in the
                // current widget tree; we intentionally avoid calling
                // ctx.requestFocus from within transient mouse events to
                // prevent those cases. A redraw is requested so the
                // hover highlight appears.
                self.focused = true;
                _ = ctx.consumeAndRedraw();
                return;
            },
            .mouse_leave => {
                self.focused = false;
                // clear transient entered state when mouse leaves
                self.entered = false;
                return;
            },
            // Allow the Enter/Return key to produce a transient "entered"
            // visual (checkered background). We do NOT trigger the click
            // callback on Enter here: the project prefers mouse-only
            // activation, but exposing a keyboard visual helps accessibility.
            .key_press => |key| {
                // Accept both explicit Enter keys and CR/LF characters
                if (key.matches(vaxis.Key.enter, .{}) or key.matches('\r', .{}) or key.matches('\n', .{})) {
                    self.entered = true;
                    // Request a redraw so the checkered background appears
                    _ = ctx.consumeAndRedraw();
                    return;
                }
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

        // fill background. when disabled render with a dotted filler to give
        // a visual cue the button is inactive. When borderless, do not draw
        // the surrounding box. Apply the widget's style to every cell so
        // callers can color buttons (chip colors).
        // If the widget is in the transient `entered` state (Enter key),
        // draw a simple checkered background by alternating glyphs per
        // cell; this gives a clear visual cue the button was "entered".
        var idx: usize = 0;
        const total = usize_w * usize_h;
        while (idx < total) : (idx += 1) {
            const row = @as(usize, idx) / usize_w;
            const col = @as(usize, idx) % usize_w;
            var glyph: []const u8 = " ";
            if (!self.enabled) {
                glyph = "·";
            } else {
                if (self.entered) {
                    // simple checkered pattern using a light block glyph
                    if ((row + col) % 2 == 0) {
                        glyph = "░";
                    } else {
                        glyph = " ";
                    }
                }
            }
            const c = &buffer[idx];
            c.char = .{ .grapheme = glyph, .width = 1 };
            // start with base style
            c.style = self.style;
            // indicate disabled visually by dimming
            if (!self.enabled) c.style.dim = true;

            // when focused/hovered, merge in focused_style: override colors
            // and set any explicit emphasis flags the caller provided.
            if (self.focused) {
                // override colors if the focused style specifies them
                if (self.focused_style.fg != .default) c.style.fg = self.focused_style.fg;
                if (self.focused_style.bg != .default) c.style.bg = self.focused_style.bg;
                if (self.focused_style.ul != .default) c.style.ul = self.focused_style.ul;
                if (self.focused_style.ul_style != .off) c.style.ul_style = self.focused_style.ul_style;

                // boolean emphasis flags: only enable if focused_style sets them true
                if (self.focused_style.bold) c.style.bold = true;
                if (self.focused_style.dim) c.style.dim = true;
                if (self.focused_style.italic) c.style.italic = true;
                if (self.focused_style.blink) c.style.blink = true;
                if (self.focused_style.reverse) c.style.reverse = true;
                if (self.focused_style.invisible) c.style.invisible = true;
                if (self.focused_style.strikethrough) c.style.strikethrough = true;
            }

            c.link = .{};
            c.image = null;
            c.default = false;
            c.wrapped = false;
            c.scale = .{};
        }

        if (!self.borderless) {
            drawBox(buffer, usize_w, usize_h);
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
