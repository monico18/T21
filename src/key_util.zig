const vaxis = @import("vaxis");

pub fn modsEmpty(m: vaxis.Key.Modifiers) bool {
    return !m.shift and !m.alt and !m.ctrl and !m.super;
}
