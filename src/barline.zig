/// Barline representation for measure delineation.
/// Supports single, double, repeat-start, repeat-end, and final barlines.
const music_theory = @import("music_theory.zig");

/// Types of barlines used in music notation.
pub const BarlineType = enum(u8) {
    single,
    double,
    free_time,
    repeat_start,
    repeat_end,
    final_barline,
};

/// Rehearsal sign attached to a barline.
pub const RehearsalSign = struct {
    letter: u8 = 0,
    description: [64]u8 = [_]u8{0} ** 64,
    description_len: u8 = 0,

    pub fn init(letter: u8) RehearsalSign {
        return .{ .letter = letter };
    }

    pub fn setDescription(self: *RehearsalSign, desc: []const u8) void {
        const len: u8 = @intCast(@min(desc.len, self.description.len));
        @memcpy(self.description[0..len], desc[0..len]);
        self.description_len = len;
    }

    pub fn getDescription(self: *const RehearsalSign) []const u8 {
        return self.description[0..self.description_len];
    }
};

/// Represents a barline with optional key/time signature changes.
pub const Barline = struct {
    position: u32 = 0,
    bar_type: BarlineType = .single,
    repeat_count: u8 = 0,
    key_signature: ?music_theory.KeySignature = null,
    time_signature: ?music_theory.TimeSignature = null,
    rehearsal_sign: ?RehearsalSign = null,

    pub fn init(bar_type: BarlineType, position: u32) Barline {
        return .{
            .bar_type = bar_type,
            .position = position,
        };
    }

    pub fn repeatStart(position: u32) Barline {
        return .{
            .bar_type = .repeat_start,
            .position = position,
        };
    }

    pub fn repeatEnd(position: u32, count: u8) Barline {
        return .{
            .bar_type = .repeat_end,
            .position = position,
            .repeat_count = count,
        };
    }

    pub fn isRepeatStart(self: Barline) bool {
        return self.bar_type == .repeat_start;
    }

    pub fn isRepeatEnd(self: Barline) bool {
        return self.bar_type == .repeat_end;
    }

    pub fn eql(self: Barline, other: Barline) bool {
        return self.position == other.position and
            self.bar_type == other.bar_type and
            self.repeat_count == other.repeat_count;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "Barline defaults" {
    const testing = @import("std").testing;
    const b = Barline.init(.single, 0);
    try testing.expectEqual(BarlineType.single, b.bar_type);
    try testing.expectEqual(@as(u32, 0), b.position);
    try testing.expect(!b.isRepeatStart());
    try testing.expect(!b.isRepeatEnd());
}

test "Repeat barlines" {
    const testing = @import("std").testing;
    const start = Barline.repeatStart(0);
    try testing.expect(start.isRepeatStart());

    const end = Barline.repeatEnd(16, 2);
    try testing.expect(end.isRepeatEnd());
    try testing.expectEqual(@as(u8, 2), end.repeat_count);
}

test "Barline with key signature change" {
    const testing = @import("std").testing;
    var b = Barline.init(.double, 8);
    b.key_signature = music_theory.KeySignature.init(.major, .flats, 1);
    try testing.expect(b.key_signature != null);
    try testing.expectEqual(@as(u8, 1), b.key_signature.?.num_accidentals);
}

test "Barline with time signature change" {
    const testing = @import("std").testing;
    var b = Barline.init(.double, 0);
    b.time_signature = music_theory.TimeSignature.init(3, 4);
    try testing.expect(b.time_signature != null);
    try testing.expectEqual(@as(u8, 3), b.time_signature.?.beats_per_measure);
}

test "Rehearsal sign" {
    const testing = @import("std").testing;
    var rs = RehearsalSign.init('A');
    rs.setDescription("Intro");
    try testing.expectEqual(@as(u8, 'A'), rs.letter);
    try testing.expectEqualStrings("Intro", rs.getDescription());
}

test "Barline equality" {
    const testing = @import("std").testing;
    const a = Barline.init(.single, 0);
    const b = Barline.init(.single, 0);
    const c = Barline.init(.double, 0);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}
