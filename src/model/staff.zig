const std = @import("std");
const measure_mod = @import("measure.zig");

pub const Measure = measure_mod.Measure;

/// A staff is a single guitar part: an ordered list of measures.
pub const Staff = struct {
    /// Index into the parent Song's `guitars` array.
    guitar_index: u8,
    /// Ordered measures. Owned slice (allocated from the song's allocator).
    measures: []Measure,

    pub fn init(guitar_index: u8, measures: []Measure) Staff {
        return .{
            .guitar_index = guitar_index,
            .measures = measures,
        };
    }

    /// Returns total tick length across all measures.
    pub fn totalTicks(self: Staff) u32 {
        var total: u32 = 0;
        for (self.measures) |m| total += m.totalTicks();
        return total;
    }

    /// Returns the measure at the given index, or null if out of range.
    pub fn measureAt(self: Staff, index: usize) ?Measure {
        if (index >= self.measures.len) return null;
        return self.measures[index];
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Staff.totalTicks empty" {
    const s = Staff.init(0, &.{});
    try std.testing.expectEqual(@as(u32, 0), s.totalTicks());
}

test "Staff.measureAt" {
    var m0 = Measure.init(4, 4, &.{});
    var m1 = Measure.init(3, 4, &.{});
    var measures = [_]Measure{ m0, m1 };
    const s = Staff.init(0, &measures);
    try std.testing.expectEqual(@as(u8, 4), s.measureAt(0).?.numerator);
    try std.testing.expectEqual(@as(u8, 3), s.measureAt(1).?.numerator);
    try std.testing.expect(s.measureAt(2) == null);
}
