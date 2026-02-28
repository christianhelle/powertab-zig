/// Guitar/instrument tuning representation.
/// Supports standard, drop, open, and custom tunings.
const music_theory = @import("music_theory.zig");

pub const max_strings: u8 = 8;
pub const min_strings: u8 = 3;

/// Represents a string tuning for an instrument.
pub const Tuning = struct {
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: u8 = 0,
    notes: [max_strings]u8 = [_]u8{0} ** max_strings,
    num_strings: u8 = 6,
    capo: u8 = 0,

    pub fn init(num_strings: u8, string_notes: []const u8) Tuning {
        var t = Tuning{};
        t.num_strings = @min(num_strings, max_strings);
        const copy_len: u8 = @min(@as(u8, @intCast(string_notes.len)), t.num_strings);
        @memcpy(t.notes[0..copy_len], string_notes[0..copy_len]);
        return t;
    }

    pub fn standardGuitar() Tuning {
        var t = init(6, &music_theory.standard_tuning);
        t.setName("Standard");
        return t;
    }

    pub fn standardBass() Tuning {
        const bass_notes = [4]u8{ 28, 33, 38, 43 }; // E1, A1, D2, G2
        var t = init(4, &bass_notes);
        t.setName("Standard Bass");
        return t;
    }

    pub fn dropD() Tuning {
        const notes = [6]u8{ 38, 45, 50, 55, 59, 64 };
        var t = init(6, &notes);
        t.setName("Drop D");
        return t;
    }

    pub fn setName(self: *Tuning, name: []const u8) void {
        const len: u8 = @intCast(@min(name.len, self.name.len));
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn getName(self: *const Tuning) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getNote(self: *const Tuning, string: u8) u8 {
        if (string >= self.num_strings) return 0;
        return self.notes[string] + self.capo;
    }

    pub fn eql(self: Tuning, other: Tuning) bool {
        if (self.num_strings != other.num_strings or self.capo != other.capo) return false;
        var i: u8 = 0;
        while (i < self.num_strings) : (i += 1) {
            if (self.notes[i] != other.notes[i]) return false;
        }
        return true;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "Standard guitar tuning" {
    const testing = @import("std").testing;
    const t = Tuning.standardGuitar();
    try testing.expectEqual(@as(u8, 6), t.num_strings);
    try testing.expectEqual(@as(u8, 40), t.getNote(0)); // E2
    try testing.expectEqual(@as(u8, 45), t.getNote(1)); // A2
    try testing.expectEqual(@as(u8, 50), t.getNote(2)); // D3
    try testing.expectEqual(@as(u8, 55), t.getNote(3)); // G3
    try testing.expectEqual(@as(u8, 59), t.getNote(4)); // B3
    try testing.expectEqual(@as(u8, 64), t.getNote(5)); // E4
    try testing.expectEqualStrings("Standard", t.getName());
}

test "Standard bass tuning" {
    const testing = @import("std").testing;
    const t = Tuning.standardBass();
    try testing.expectEqual(@as(u8, 4), t.num_strings);
    try testing.expectEqual(@as(u8, 28), t.getNote(0)); // E1
    try testing.expectEqual(@as(u8, 33), t.getNote(1)); // A1
    try testing.expectEqualStrings("Standard Bass", t.getName());
}

test "Drop D tuning" {
    const testing = @import("std").testing;
    const t = Tuning.dropD();
    try testing.expectEqual(@as(u8, 38), t.getNote(0)); // D2
    try testing.expectEqual(@as(u8, 45), t.getNote(1)); // A2 (unchanged)
    try testing.expectEqualStrings("Drop D", t.getName());
}

test "Capo affects pitch" {
    const testing = @import("std").testing;
    var t = Tuning.standardGuitar();
    t.capo = 2;
    try testing.expectEqual(@as(u8, 42), t.getNote(0)); // E2 + 2 = F#2
    try testing.expectEqual(@as(u8, 47), t.getNote(1)); // A2 + 2 = B2
}

test "Tuning equality" {
    const testing = @import("std").testing;
    const a = Tuning.standardGuitar();
    const b = Tuning.standardGuitar();
    const c = Tuning.dropD();
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "Out of range string returns 0" {
    const testing = @import("std").testing;
    const t = Tuning.standardGuitar();
    try testing.expectEqual(@as(u8, 0), t.getNote(6));
    try testing.expectEqual(@as(u8, 0), t.getNote(255));
}
