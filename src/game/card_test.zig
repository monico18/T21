const std = @import("std");
const Rank = @import("card.zig").Rank;

test "rank labels are sane" {
    try std.testing.expect(std.mem.eql(u8, Rank.two.label(), "2"));
    try std.testing.expect(std.mem.eql(u8, Rank.ten.label(), "10"));
    try std.testing.expect(std.mem.eql(u8, Rank.jack.label(), "J"));
    try std.testing.expect(std.mem.eql(u8, Rank.ace.label(), "A"));
}
