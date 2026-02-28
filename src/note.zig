/// Note representation for guitar tablature.
/// A note sits on a specific string at a specific fret, with optional
/// properties like hammer-on, pull-off, bend, slide, etc.

/// Simple boolean properties a note can have.
pub const NoteProperty = enum(u8) {
    tied,
    muted,
    hammer_on,
    pull_off,
    natural_harmonic,
    ghost_note,
    octave_8va,
    octave_15ma,
    octave_8vb,
    octave_15mb,
    slide_in_from_below,
    slide_in_from_above,
    shift_slide,
    legato_slide,
    slide_out_down,
    slide_out_up,
    let_ring,
    palm_mute,
    staccato,
    accent,
    tap,
};

/// Bend types for string bending notation.
pub const BendType = enum(u8) {
    normal_bend,
    bend_and_release,
    bend_and_hold,
    pre_bend,
    pre_bend_and_release,
    pre_bend_and_hold,
    gradual_release,
    immediate_release,
};

/// Bend information attached to a note.
pub const Bend = struct {
    bend_type: BendType = .normal_bend,
    bent_pitch: u8 = 4,
    release_pitch: u8 = 0,
    duration: u8 = 0,

    pub fn init(bend_type: BendType, bent_pitch: u8) Bend {
        return .{
            .bend_type = bend_type,
            .bent_pitch = bent_pitch,
        };
    }

    pub fn eql(self: Bend, other: Bend) bool {
        return self.bend_type == other.bend_type and
            self.bent_pitch == other.bent_pitch and
            self.release_pitch == other.release_pitch and
            self.duration == other.duration;
    }
};

pub const max_fret: u8 = 29;
pub const max_strings: u8 = 8;
pub const max_properties: u32 = 21;

/// Represents a single note on the fretboard.
pub const Note = struct {
    string: u8 = 0,
    fret: u8 = 0,
    properties: u32 = 0,
    trill_fret: ?u8 = null,
    bend: ?Bend = null,

    pub fn init(string: u8, fret: u8) Note {
        return .{
            .string = string,
            .fret = fret,
        };
    }

    pub fn hasProperty(self: Note, prop: NoteProperty) bool {
        return (self.properties & (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(prop))))) != 0;
    }

    pub fn setProperty(self: *Note, prop: NoteProperty, value: bool) void {
        const mask = @as(u32, 1) << @as(u5, @intCast(@intFromEnum(prop)));
        if (value) {
            self.properties |= mask;
        } else {
            self.properties &= ~mask;
        }
    }

    pub fn eql(self: Note, other: Note) bool {
        return self.string == other.string and
            self.fret == other.fret and
            self.properties == other.properties;
    }

    pub fn isTied(self: Note) bool {
        return self.hasProperty(.tied);
    }

    pub fn isMuted(self: Note) bool {
        return self.hasProperty(.muted);
    }

    pub fn isGhostNote(self: Note) bool {
        return self.hasProperty(.ghost_note);
    }

    pub fn isNaturalHarmonic(self: Note) bool {
        return self.hasProperty(.natural_harmonic);
    }

    pub fn hasBend(self: Note) bool {
        return self.bend != null;
    }

    pub fn hasTrill(self: Note) bool {
        return self.trill_fret != null;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "Note init and defaults" {
    const testing = @import("std").testing;
    const n = Note.init(2, 5);
    try testing.expectEqual(@as(u8, 2), n.string);
    try testing.expectEqual(@as(u8, 5), n.fret);
    try testing.expectEqual(@as(u32, 0), n.properties);
    try testing.expect(!n.isTied());
    try testing.expect(!n.isMuted());
}

test "Note property flags" {
    const testing = @import("std").testing;
    var n = Note.init(0, 3);
    n.setProperty(.hammer_on, true);
    try testing.expect(n.hasProperty(.hammer_on));
    try testing.expect(!n.hasProperty(.pull_off));

    n.setProperty(.pull_off, true);
    try testing.expect(n.hasProperty(.hammer_on));
    try testing.expect(n.hasProperty(.pull_off));

    n.setProperty(.hammer_on, false);
    try testing.expect(!n.hasProperty(.hammer_on));
    try testing.expect(n.hasProperty(.pull_off));
}

test "Note tied and muted" {
    const testing = @import("std").testing;
    var n = Note.init(0, 0);
    n.setProperty(.tied, true);
    try testing.expect(n.isTied());
    n.setProperty(.muted, true);
    try testing.expect(n.isMuted());
}

test "Note ghost note and natural harmonic" {
    const testing = @import("std").testing;
    var n = Note.init(3, 12);
    n.setProperty(.ghost_note, true);
    try testing.expect(n.isGhostNote());
    n.setProperty(.natural_harmonic, true);
    try testing.expect(n.isNaturalHarmonic());
}

test "Note equality" {
    const testing = @import("std").testing;
    const a = Note.init(1, 5);
    const b = Note.init(1, 5);
    const c = Note.init(2, 5);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "Note bend" {
    const testing = @import("std").testing;
    var n = Note.init(2, 7);
    try testing.expect(!n.hasBend());
    n.bend = Bend.init(.normal_bend, 4);
    try testing.expect(n.hasBend());
}

test "Note trill" {
    const testing = @import("std").testing;
    var n = Note.init(2, 5);
    try testing.expect(!n.hasTrill());
    n.trill_fret = 7;
    try testing.expect(n.hasTrill());
    try testing.expectEqual(@as(u8, 7), n.trill_fret.?);
}

test "Bend equality" {
    const testing = @import("std").testing;
    const a = Bend.init(.normal_bend, 4);
    const b = Bend.init(.normal_bend, 4);
    const c = Bend.init(.pre_bend, 4);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "All note properties can be set" {
    const testing = @import("std").testing;
    var n = Note.init(0, 0);
    const props = [_]NoteProperty{
        .tied,           .muted,          .hammer_on,
        .pull_off,       .natural_harmonic, .ghost_note,
        .octave_8va,     .octave_15ma,    .octave_8vb,
        .octave_15mb,    .slide_in_from_below, .slide_in_from_above,
        .shift_slide,    .legato_slide,   .slide_out_down,
        .slide_out_up,   .let_ring,       .palm_mute,
        .staccato,       .accent,         .tap,
    };
    for (props) |p| {
        n.setProperty(p, true);
        try testing.expect(n.hasProperty(p));
    }
}
