/// Staff representation containing voices with positions and notes.
/// Each staff maps to a player/instrument and contains 1-2 voices.
const position_mod = @import("position.zig");
const Position = position_mod.Position;
const DurationType = position_mod.DurationType;

pub const max_voices: u8 = 2;
pub const max_positions_per_voice: usize = 64;

/// Represents a single voice within a staff.
pub const Voice = struct {
    positions: [max_positions_per_voice]Position = [_]Position{Position.init(0, .eighth)} ** max_positions_per_voice,
    position_count: u16 = 0,

    pub fn addPosition(self: *Voice, pos: Position) bool {
        if (self.position_count >= max_positions_per_voice) return false;
        self.positions[self.position_count] = pos;
        self.position_count += 1;
        return true;
    }

    pub fn getPositions(self: *const Voice) []const Position {
        return self.positions[0..self.position_count];
    }

    pub fn getPositionAt(self: *const Voice, pos_idx: u32) ?*const Position {
        for (self.positions[0..self.position_count]) |*p| {
            if (p.position == pos_idx) return p;
        }
        return null;
    }

    pub fn getPositionAtMut(self: *Voice, pos_idx: u32) ?*Position {
        for (self.positions[0..self.position_count]) |*p| {
            if (p.position == pos_idx) return p;
        }
        return null;
    }

    pub fn isEmpty(self: *const Voice) bool {
        return self.position_count == 0;
    }
};

/// Number of strings in a standard guitar staff.
pub const default_num_strings: u8 = 6;

/// Clef type for the staff.
pub const ClefType = enum(u8) {
    treble,
    bass,
};

/// Represents a staff within a system.
pub const Staff = struct {
    num_strings: u8 = default_num_strings,
    clef: ClefType = .treble,
    voices: [max_voices]Voice = [_]Voice{Voice{}} ** max_voices,

    pub fn init(num_strings: u8) Staff {
        return .{ .num_strings = num_strings };
    }

    pub fn getVoice(self: *const Staff, voice_idx: u8) *const Voice {
        if (voice_idx >= max_voices) return &self.voices[0];
        return &self.voices[voice_idx];
    }

    pub fn getVoiceMut(self: *Staff, voice_idx: u8) *Voice {
        if (voice_idx >= max_voices) return &self.voices[0];
        return &self.voices[voice_idx];
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "Voice add and get positions" {
    const testing = @import("std").testing;
    const note_mod = @import("note.zig");
    var v = Voice{};
    try testing.expect(v.isEmpty());

    var p = Position.init(0, .quarter);
    _ = p.addNote(note_mod.Note.init(0, 3));
    try testing.expect(v.addPosition(p));
    try testing.expect(!v.isEmpty());

    const positions = v.getPositions();
    try testing.expectEqual(@as(usize, 1), positions.len);
    try testing.expectEqual(@as(u32, 0), positions[0].position);
}

test "Voice find position at index" {
    const testing = @import("std").testing;
    var v = Voice{};
    _ = v.addPosition(Position.init(0, .quarter));
    _ = v.addPosition(Position.init(4, .eighth));
    _ = v.addPosition(Position.init(8, .half));

    const found = v.getPositionAt(4);
    try testing.expect(found != null);
    try testing.expectEqual(DurationType.eighth, found.?.duration_type);

    try testing.expect(v.getPositionAt(99) == null);
}

test "Staff defaults" {
    const testing = @import("std").testing;
    const s = Staff.init(6);
    try testing.expectEqual(@as(u8, 6), s.num_strings);
    try testing.expectEqual(ClefType.treble, s.clef);
}

test "Staff voice access" {
    const testing = @import("std").testing;
    var s = Staff.init(6);
    const v = s.getVoiceMut(0);
    _ = v.addPosition(Position.init(0, .quarter));
    try testing.expectEqual(@as(u16, 1), s.voices[0].position_count);
}
