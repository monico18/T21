const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Card = @import("../../game/card.zig").Card;
const CardWidget = @import("card_widget.zig").CardWidget;

/// Draws a horizontal row of cards.
/// Works with Vaxis 0.5.1 by combining child surfaces.
pub const HandWidget = struct {
    cards: []const Card,
    hide_first: bool = false, // hide dealer's first card

    pub fn init(cards: []const Card, hide_first: bool) HandWidget {
        return .{
            .cards = cards,
            .hide_first = hide_first,
        };
    }

    pub fn widget(self: *HandWidget) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = HandWidget.onEvent,
            .drawFn = HandWidget.onDraw,
        };
    }

    fn onEvent(
        _: *anyopaque,
        _: *vxfw.EventContext,
        _: vxfw.Event,
    ) anyerror!void {
        // HandWidget is non-interactive
        return;
    }

    fn onDraw(ptr: *anyopaque, ctx: vxfw.DrawContext) !vxfw.Surface {
        const self: *HandWidget = @ptrCast(@alignCast(ptr));
        const arena = ctx.arena;

        const count = self.cards.len;
        if (count == 0) {
            // empty surface
            return .{
                .size = .{ .width = 0, .height = 0 },
                .widget = self.widget(),
                .buffer = &.{},
                .children = &.{},
            };
        }

        // We will gather SubSurfaces for each card
        const children = try arena.alloc(vxfw.SubSurface, count);

        var total_width: usize = 0;
        var max_height: usize = 0;

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const card = self.cards[i];
            const face_down = (i == 0 and self.hide_first);

            var cw = CardWidget.init(card, face_down);
            const cw_widget = cw.widget();
            const card_surf = try cw_widget.drawFn(cw_widget.userdata, ctx);

            // position horizontally
            children[i] = .{
                .origin = .{ .row = @intCast(0), .col = @intCast(total_width) },
                .surface = card_surf,
            };

            total_width += card_surf.size.width;
            if (card_surf.size.height > max_height)
                max_height = card_surf.size.height;
        }

        return .{
            .size = .{ .width = @intCast(total_width), .height = @intCast(max_height) },
            .widget = self.widget(),
            .buffer = &.{}, // no root buffer in 0.5.x custom widgets
            .children = children,
        };
    }
};
