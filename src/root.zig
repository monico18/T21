pub const game = struct {
    pub const Card = @import("game/card.zig");
    pub const Deck = @import("game/deck.zig");
    pub const Hand = @import("game/hand.zig");
    pub const Player = @import("game/player.zig");
    pub const Rules = @import("game/rules.zig");
    pub const State = @import("game/state.zig");
};

pub const ui = struct {
    pub const Model = @import("ui/model.zig").Model;

    pub const screens = struct {
        pub const Menu = @import("ui/screens/menu.zig").MenuScreen;
        pub const Betting = @import("ui/screens/betting.zig").BettingScreen;
        pub const Table = @import("ui/screens/table.zig").TableScreen;
        pub const Results = @import("ui/screens/results.zig").ResultsScreen;
    };

    pub const widgets = struct {
        pub const Button = @import("ui/widgets/button_widget.zig").ButtonWidget;
        pub const CardWidget = @import("ui/widgets/card_widget.zig").CardWidget;
        pub const HandWidget = @import("ui/widgets/hand_widget.zig").HandWidget;
        pub const StatusWidget = @import("ui/widgets/status_widget.zig").StatusWidget;
    };
};

// re-export common types at the top level if convenient:
pub const Model = ui.Model;
pub const GameState = game.State;
