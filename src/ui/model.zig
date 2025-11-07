const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const GameState = @import("../game/state.zig").GameState;
pub const Screen = enum {
    menu,
    betting,
    table,
    results,
};

const menu = @import("screens/menu.zig");
const betting = @import("screens/betting.zig");
const table = @import("screens/table.zig");
const results = @import("screens/results.zig");

const StatusWidget = @import("widgets/status_widget.zig").StatusWidget;

pub const Model = struct {
    allocator: std.mem.Allocator,
    game: GameState,

    current_screen: Screen,

    // Global status bar
    status: StatusWidget,

    // When a round ends while the player is still viewing the table, we
    // briefly hold on the table screen for a few frames so the player can
    // see their final cards (e.g., Blackjack) before automatically
    // switching to the results screen. This is a frame-based delay; the
    // draw loop decrements the counter once per frame.
    results_delay_frames: u32 = 30,
    results_hold_counter: u32 = 0,

    // Screens
    menu_screen: menu.MenuScreen,
    betting_screen: betting.BettingScreen,
    table_screen: table.TableScreen,
    results_screen: results.ResultsScreen,

    pub fn init(allocator: std.mem.Allocator, num_decks: usize, starting_money: i32) !*Model {
        var model = try allocator.create(Model);

        // Initialize game
        model.allocator = allocator;
        model.game = try GameState.init(allocator, num_decks, starting_money);
        // Try to load a previously saved bankroll if present. Ignore errors
        // (e.g., file not found or malformed) so the game still starts.
        _ = model.game.loadBankroll("bankroll.bin") catch {};
        model.current_screen = .menu;

        // Initialize global status widget
        model.status = StatusWidget.init();

        // Initialize screens (MUST be after model is allocated)
        model.menu_screen = menu.MenuScreen.init(model);
        model.betting_screen = try betting.BettingScreen.init(model, &model.game);
        // Initialize table screen (store the game pointer into the screen)
        model.table_screen = table.TableScreen.init(&model.game);
        // BettingScreen.init leaves button userdata null to avoid taking the
        // address of a stack-local value. Set userdata to point to the
        // stored betting_screen now that it's placed inside `model`.
        model.betting_screen.plus_btn.userdata = &model.betting_screen;
        model.betting_screen.plus25_btn.userdata = &model.betting_screen;
        model.betting_screen.plus50_btn.userdata = &model.betting_screen;
        model.betting_screen.plus100_btn.userdata = &model.betting_screen;
        model.betting_screen.plus10_btn.userdata = &model.betting_screen;
        model.betting_screen.plus100_btn.userdata = &model.betting_screen;
        model.betting_screen.minus_btn.userdata = &model.betting_screen;
        model.betting_screen.minus25_btn.userdata = &model.betting_screen;
        model.betting_screen.minus50_btn.userdata = &model.betting_screen;
        model.betting_screen.minus100_btn.userdata = &model.betting_screen;
        model.betting_screen.minus10_btn.userdata = &model.betting_screen;
        model.betting_screen.all_in_btn.userdata = &model.betting_screen;
        model.betting_screen.clear_btn.userdata = &model.betting_screen;
        model.betting_screen.confirm_btn.userdata = &model.betting_screen;
        model.betting_screen.back_btn.userdata = &model.betting_screen;
        model.table_screen.hit_btn.userdata = &model.table_screen;
        model.table_screen.stand_btn.userdata = &model.table_screen;
        model.table_screen.double_btn.userdata = &model.table_screen;
        model.results_screen = results.ResultsScreen.init(model, &model.game);
        // ResultsScreen.init leaves play_again_btn.userdata null to avoid
        // taking the address of a stack-local value. Now that the
        // ResultsScreen is stored in `model`, point the button userdata to it.
        model.results_screen.play_again_btn.userdata = &model.results_screen;
        model.results_screen.save_btn.userdata = &model.results_screen;

        return model;
    }

    pub fn deinit(self: *Model) void {
        self.game.deinit();
        self.allocator.destroy(self);
    }

    pub fn widget(self: *Model) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = Model.typeErasedEventHandler,
            .drawFn = Model.typeErasedDrawFn,
        };
    }

    fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
        const self: *Model = @ptrCast(@alignCast(ptr));

        switch (self.current_screen) {
            .menu => try self.menu_screen.handleEvent(self, ctx, event),
            .betting => try self.betting_screen.handleEvent(self, ctx, event),
            .table => try self.table_screen.handleEvent(self, ctx, event),
            .results => try self.results_screen.handleEvent(self, ctx, event),
        }
    }

    fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) !vxfw.Surface {
        const self: *Model = @ptrCast(@alignCast(ptr));

        // If the game phase has reached results, ensure the UI shows the
        // results screen automatically. When the player is currently
        // viewing the table we briefly hold on the table screen so they
        // can see their final cards (e.g., Blackjack) before switching to
        // the results screen. This is a simple frame-based delay.
        if (self.game.phase == .results) {
            if (self.current_screen == .table) {
                if (self.results_hold_counter == 0) {
                    // initialize the hold counter when we first observe
                    // results while on the table
                    self.results_hold_counter = self.results_delay_frames;
                } else {
                    // decrement each draw frame; when it reaches zero we
                    // actually flip to the results screen
                    self.results_hold_counter -= 1;
                    if (self.results_hold_counter == 0) {
                        self.current_screen = .results;
                    }
                }
            } else {
                // not currently on table; go straight to results
                self.current_screen = .results;
            }
        } else {
            // clear any pending hold when not in results phase
            self.results_hold_counter = 0;
        }

        return switch (self.current_screen) {
            .menu => self.menu_screen.draw(self, ctx),
            .betting => self.betting_screen.draw(self, ctx),
            .table => self.table_screen.draw(self, ctx),
            .results => self.results_screen.draw(self, ctx),
        };
    }
};
