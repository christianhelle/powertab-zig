/// Music theory constants and utilities for PowerTab Editor.
/// Provides note names, intervals, and MIDI pitch calculations.

/// Standard tuning MIDI note values for a 6-string guitar (E2 to E4).
pub const standard_tuning = [6]u8{ 40, 45, 50, 55, 59, 64 };

/// Note names in chromatic order.
pub const note_names = [12][]const u8{
    "C", "C#", "D", "D#", "E", "F",
    "F#", "G", "G#", "A", "A#", "B",
};

/// Flat note names in chromatic order.
pub const flat_note_names = [12][]const u8{
    "C", "Db", "D", "Eb", "E", "F",
    "Gb", "G", "Ab", "A", "Bb", "B",
};

/// Key signature types.
pub const KeyType = enum(u8) {
    major,
    minor,
};

/// Accidental types for key signatures.
pub const AccidentalType = enum(u8) {
    sharps,
    flats,
};

/// Represents a key signature (e.g. G major = 1 sharp, F major = 1 flat).
pub const KeySignature = struct {
    key_type: KeyType = .major,
    accidental_type: AccidentalType = .sharps,
    num_accidentals: u8 = 0,

    pub fn init(key_type: KeyType, accidental_type: AccidentalType, num_accidentals: u8) KeySignature {
        return .{
            .key_type = key_type,
            .accidental_type = accidental_type,
            .num_accidentals = num_accidentals,
        };
    }

    pub fn eql(self: KeySignature, other: KeySignature) bool {
        return self.key_type == other.key_type and
            self.accidental_type == other.accidental_type and
            self.num_accidentals == other.num_accidentals;
    }
};

/// Represents a time signature (e.g. 4/4, 3/4, 6/8).
pub const TimeSignature = struct {
    beats_per_measure: u8 = 4,
    beat_value: u8 = 4,
    visible: bool = true,

    pub fn init(beats: u8, value: u8) TimeSignature {
        return .{
            .beats_per_measure = beats,
            .beat_value = value,
        };
    }

    pub fn eql(self: TimeSignature, other: TimeSignature) bool {
        return self.beats_per_measure == other.beats_per_measure and
            self.beat_value == other.beat_value and
            self.visible == other.visible;
    }
};

/// Represents a tempo marking (BPM and beat type).
pub const TempoMarker = struct {
    pub const BeatType = enum(u8) {
        half = 2,
        dotted_half = 3,
        quarter = 4,
        dotted_quarter = 6,
        eighth = 8,
        dotted_eighth = 12,
        sixteenth = 16,
    };

    beat_type: BeatType = .quarter,
    bpm: u16 = 120,
    description: [64]u8 = [_]u8{0} ** 64,
    description_len: u8 = 0,
    position: u32 = 0,

    pub fn init(beat_type: BeatType, bpm: u16) TempoMarker {
        return .{
            .beat_type = beat_type,
            .bpm = bpm,
        };
    }

    pub fn eql(self: TempoMarker, other: TempoMarker) bool {
        return self.beat_type == other.beat_type and
            self.bpm == other.bpm and
            self.position == other.position;
    }

    pub fn setDescription(self: *TempoMarker, desc: []const u8) void {
        const len: u8 = @intCast(@min(desc.len, self.description.len));
        @memcpy(self.description[0..len], desc[0..len]);
        self.description_len = len;
    }

    pub fn getDescription(self: *const TempoMarker) []const u8 {
        return self.description[0..self.description_len];
    }
};

/// Calculates MIDI note number from string tuning and fret number.
pub fn midiNote(string_tuning: u8, fret: u8) u8 {
    return string_tuning + fret;
}

/// Returns the note name for a given MIDI note number.
pub fn noteName(midi: u8) []const u8 {
    return note_names[midi % 12];
}

/// Returns the octave for a given MIDI note number.
pub fn noteOctave(midi: u8) u8 {
    return midi / 12 - 1;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "standard tuning MIDI values" {
    const testing = @import("std").testing;
    // E2=40, A2=45, D3=50, G3=55, B3=59, E4=64
    try testing.expectEqual(@as(u8, 40), standard_tuning[0]);
    try testing.expectEqual(@as(u8, 45), standard_tuning[1]);
    try testing.expectEqual(@as(u8, 50), standard_tuning[2]);
    try testing.expectEqual(@as(u8, 55), standard_tuning[3]);
    try testing.expectEqual(@as(u8, 59), standard_tuning[4]);
    try testing.expectEqual(@as(u8, 64), standard_tuning[5]);
}

test "midiNote calculates correctly" {
    const testing = @import("std").testing;
    // Open low E string = 40, fret 5 = 45 (A)
    try testing.expectEqual(@as(u8, 45), midiNote(40, 5));
    // 12th fret of low E = 52
    try testing.expectEqual(@as(u8, 52), midiNote(40, 12));
}

test "noteName returns correct name" {
    const testing = @import("std").testing;
    try testing.expectEqualStrings("E", noteName(40)); // E2
    try testing.expectEqualStrings("A", noteName(45)); // A2
    try testing.expectEqualStrings("C", noteName(60)); // C4 (middle C)
}

test "noteOctave returns correct octave" {
    const testing = @import("std").testing;
    try testing.expectEqual(@as(u8, 2), noteOctave(40)); // E2
    try testing.expectEqual(@as(u8, 4), noteOctave(60)); // C4
}

test "KeySignature equality" {
    const testing = @import("std").testing;
    const g_major = KeySignature.init(.major, .sharps, 1);
    const g_major2 = KeySignature.init(.major, .sharps, 1);
    const f_major = KeySignature.init(.major, .flats, 1);
    try testing.expect(g_major.eql(g_major2));
    try testing.expect(!g_major.eql(f_major));
}

test "TimeSignature default is 4/4" {
    const testing = @import("std").testing;
    const ts = TimeSignature{};
    try testing.expectEqual(@as(u8, 4), ts.beats_per_measure);
    try testing.expectEqual(@as(u8, 4), ts.beat_value);
}

test "TempoMarker description" {
    const testing = @import("std").testing;
    var tm = TempoMarker.init(.quarter, 140);
    tm.setDescription("Allegro");
    try testing.expectEqualStrings("Allegro", tm.getDescription());
}
