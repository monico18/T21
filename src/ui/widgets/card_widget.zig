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
                .widget = .{
                    .userdata = @ptrCast(&nonInteractiveSentinel),
                    .eventHandler = null,
                    .drawFn = nonInteractiveCardDraw,
                },
                .buffer = &_empty_card_cells,
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

        // Choose a style for red suits (hearts, diamonds). If the suit is
        // red, use a red foreground; otherwise use the default style.
        const suit_style = if (self.card.suit.isRed())
            vaxis.Style{ .fg = vaxis.Color{ .rgb = [3]u8{ 0xFF, 0x00, 0x00 } } }
        else
            vaxis.Style{};

        // top-left rank and suit (rank in default, suit colored for red suits)
        children[4] = try makeTextSub(ctx, 1, 1, rank, .{});
        children[5] = try makeTextSub(ctx, 2, 1, suit, suit_style);

        // center suit (colored if red)
        const center_col: usize = (width / 2) - 1;
        children[6] = try makeTextSub(ctx, height / 2, center_col, suit, suit_style);

        // This widget is created on the stack for drawing only. Returning
        // a widget that contains a userdata pointer to the stack-local
        // CardWidget would leave stale pointers in the surface and can
        // cause event-path/focus handling to crash. Use an empty
        // (non-interactive) widget here so the returned surface is
        // draw-only.
        return .{
            .size = .{ .width = @intCast(width), .height = @intCast(height) },
            .widget = .{
                .userdata = @ptrCast(&nonInteractiveSentinel),
                .eventHandler = null,
                .drawFn = nonInteractiveCardDraw,
            },
            .buffer = &_empty_card_cells,
            .children = children,
        };
    }
};

// Stable sentinel used as userdata for non-interactive temporary widgets.
var nonInteractiveSentinel: u8 = 0;
var _empty_card_cells: [0]vaxis.Cell = .{};
var _empty_card_children: [0]vxfw.SubSurface = .{};

fn nonInteractiveCardDraw(ptr: *anyopaque, ctx: vxfw.DrawContext) error{OutOfMemory}!vxfw.Surface {
    // silence unused-parameters
    _ = ptr;
    _ = ctx;
    // Return an empty non-interactive surface. The widget field points to
    // a stable sentinel and uses this same draw function so drawFn is
    // non-null.
    return .{
        .size = .{ .width = 0, .height = 0 },
        .widget = .{
            .userdata = @ptrCast(&nonInteractiveSentinel),
            .eventHandler = null,
            .drawFn = nonInteractiveCardDraw,
        },
        .buffer = &_empty_card_cells,
        .children = &_empty_card_children,
    };
}

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
