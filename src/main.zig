const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @import("root.zig").Model;

pub fn main() !void {
    // -------------------------------------------------------------
    // Allocator
    // -------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // -------------------------------------------------------------
    // Create Vaxis App
    // -------------------------------------------------------------
    var app = try vxfw.App.init(allocator);
    defer app.deinit();

    // -------------------------------------------------------------
    // Create our Blackjack model
    // Choose deck count + starting money as you like
    // -------------------------------------------------------------
    const num_decks: usize = 4;
    const starting_money: i32 = 500;

    const model = try Model.init(allocator, num_decks, starting_money);
    defer model.deinit();

    // IMPORTANT:
    // Vaxis needs a pointer to the Model,
    // so we allocate it on the heap.
    const model_ptr = try allocator.create(Model);
    defer allocator.destroy(model_ptr);

    // -------------------------------------------------------------
    // Run the TUI app
    // -------------------------------------------------------------
    try app.run(model.widget(), .{});
}
