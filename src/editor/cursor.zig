const std = @import("std");

/// Identifies a position within the tab grid.
pub const Cursor = struct {
    /// Current staff index (0-based).
    staff: usize,
    /// Current measure index within the staff (0-based).
    measure: usize,
    /// Current beat/position index within the measure (0-based).
    position: usize,
    /// Currently selected string for note entry (0 = highest string).
    string: usize,

    pub fn init() Cursor {
        return .{ .staff = 0, .measure = 0, .position = 0, .string = 0 };
    }

    /// Move the cursor left (to the previous beat), wrapping to the
    /// previous measure when necessary.  Returns false if already at the start.
    pub fn moveLeft(self: *Cursor, positions_in_measure: usize) bool {
        _ = positions_in_measure;
        if (self.position > 0) {
            self.position -= 1;
            return true;
        }
        if (self.measure > 0) {
            self.measure -= 1;
            self.position = 0;
            return true;
        }
        return false;
    }

    /// Move the cursor right (to the next beat).  Returns false if already at
    /// or beyond the last position in the current measure.
    pub fn moveRight(self: *Cursor, positions_in_measure: usize) bool {
        if (self.position + 1 < positions_in_measure) {
            self.position += 1;
            return true;
        }
        return false;
    }

    /// Move cursor up (to a higher string index = lower-pitched string).
    pub fn moveUp(self: *Cursor, string_count: usize) bool {
        if (self.string + 1 < string_count) {
            self.string += 1;
            return true;
        }
        return false;
    }

    /// Move cursor down (to a lower string index = higher-pitched string).
    pub fn moveDown(self: *Cursor) bool {
        if (self.string > 0) {
            self.string -= 1;
            return true;
        }
        return false;
    }

    /// Jump to the next measure, first position.
    pub fn nextMeasure(self: *Cursor, measure_count: usize) bool {
        if (self.measure + 1 < measure_count) {
            self.measure += 1;
            self.position = 0;
            return true;
        }
        return false;
    }

    /// Jump to the previous measure, first position.
    pub fn prevMeasure(self: *Cursor) bool {
        if (self.measure > 0) {
            self.measure -= 1;
            self.position = 0;
            return true;
        }
        return false;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Cursor.init" {
    const c = Cursor.init();
    try std.testing.expectEqual(@as(usize, 0), c.staff);
    try std.testing.expectEqual(@as(usize, 0), c.measure);
    try std.testing.expectEqual(@as(usize, 0), c.position);
    try std.testing.expectEqual(@as(usize, 0), c.string);
}

test "Cursor.moveRight within measure" {
    var c = Cursor.init();
    try std.testing.expect(c.moveRight(4));
    try std.testing.expectEqual(@as(usize, 1), c.position);
}

test "Cursor.moveRight at end returns false" {
    var c = Cursor{ .staff = 0, .measure = 0, .position = 3, .string = 0 };
    try std.testing.expect(!c.moveRight(4)); // 4 positions → index 0..3
}

test "Cursor.moveLeft" {
    var c = Cursor{ .staff = 0, .measure = 0, .position = 2, .string = 0 };
    try std.testing.expect(c.moveLeft(4));
    try std.testing.expectEqual(@as(usize, 1), c.position);
}

test "Cursor.moveLeft at start returns false" {
    var c = Cursor.init();
    try std.testing.expect(!c.moveLeft(4));
}

test "Cursor.moveUp and moveDown" {
    var c = Cursor.init(); // string = 0 (highest)
    try std.testing.expect(c.moveUp(6));
    try std.testing.expectEqual(@as(usize, 1), c.string);
    try std.testing.expect(c.moveDown());
    try std.testing.expectEqual(@as(usize, 0), c.string);
    try std.testing.expect(!c.moveDown()); // already at 0
}

test "Cursor.nextMeasure and prevMeasure" {
    var c = Cursor.init();
    try std.testing.expect(c.nextMeasure(3));
    try std.testing.expectEqual(@as(usize, 1), c.measure);
    try std.testing.expect(c.prevMeasure());
    try std.testing.expectEqual(@as(usize, 0), c.measure);
    try std.testing.expect(!c.prevMeasure());
}
