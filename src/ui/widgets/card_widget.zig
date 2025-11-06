const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Card = @import("../../game/card.zig").Card;

/// Draws a card using child surfaces (Text widgets).
pub const CardWidget = struct {
    card: Card,
    face_down: bool = false,

    pub fn init(card: Card, face_down: bool) CardWidget {
        return .{ .card = card, .face_down = face_down };
    }

    pub fn widget(self: *CardWidget) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = onEvent,
            .drawFn = onDraw,
        };
    }

    fn onEvent(_: *anyopaque, _: *vxfw.EventContext, _: vxfw.Event) anyerror!void {
        return;
    }

    fn onDraw(ptr: *anyopaque, ctx: vxfw.DrawContext) !vxfw.Surface {
        const self: *CardWidget = @ptrCast(@alignCast(ptr));
        const arena = ctx.arena;

        // Card size (small fixed card)
        const width: usize = 9;
        const height: usize = 7;

        // We'll construct a list of SubSurfaces: 4 corners + rank/suit texts.
        const base_children_count: usize = 4; // corners
        const extra_faceup = 3; // top-left rank, top-left suit, center suit

        if (self.face_down) {
            const children = try arena.alloc(vxfw.SubSurface, base_children_count + 1);

            // corners
            children[0] = try makeTextSub(ctx, 0, 0, "┌", .{});
            children[1] = try makeTextSub(ctx, 0, width - 1, "┐", .{});
            children[2] = try makeTextSub(ctx, height - 1, 0, "└", .{});
            children[3] = try makeTextSub(ctx, height - 1, width - 1, "┘", .{});

            // center filler
            const filler = "▒▒▒";
            const fill_col: usize = (width / 2) - (filler.len / 2);
            children[4] = try makeTextSub(ctx, height / 2, fill_col, filler, .{});

            return .{
                .size = .{ .width = @intCast(width), .height = @intCast(height) },
                .widget = self.widget(),
                .buffer = &.{},
                .children = children,
            };
        }

        // face-up
        const children = try arena.alloc(vxfw.SubSurface, base_children_count + extra_faceup);
        children[0] = try makeTextSub(ctx, 0, 0, "┌", .{});
        children[1] = try makeTextSub(ctx, 0, width - 1, "┐", .{});
        children[2] = try makeTextSub(ctx, height - 1, 0, "└", .{});
        children[3] = try makeTextSub(ctx, height - 1, width - 1, "┘", .{});

        const rank = self.card.rank.label();
        const suit = self.card.suit.symbol();

        // top-left rank and suit (no color for now)
        children[4] = try makeTextSub(ctx, 1, 1, rank, .{});
        children[5] = try makeTextSub(ctx, 2, 1, suit, .{});

        // center suit
        const center_col: usize = (width / 2) - 1;
        children[6] = try makeTextSub(ctx, height / 2, center_col, suit, .{});

        return .{
            .size = .{ .width = @intCast(width), .height = @intCast(height) },
            .widget = self.widget(),
            .buffer = &.{},
            .children = children,
        };
    }
};

//
// Helpers
//
fn makeTextSub(
    ctx: vxfw.DrawContext,
    row: usize,
    col: usize,
    str: []const u8,
    style: vaxis.Style,
) !vxfw.SubSurface {
    const txt = vxfw.Text{
        .text = str,
        .style = style,
    };
    const surf = try txt.draw(ctx);
    return vxfw.SubSurface{
        .origin = .{ .row = @intCast(row), .col = @intCast(col) },
        .surface = surf,
    };
}
