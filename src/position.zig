/// A Position represents a rhythmic location within a staff, containing
/// zero or more notes along with duration and articulation properties.
const note_mod = @import("note.zig");
const Note = note_mod.Note;

/// Duration types for note/rest values.
pub const DurationType = enum(u8) {
    whole = 1,
    half = 2,
    quarter = 4,
    eighth = 8,
    sixteenth = 16,
    thirty_second = 32,
    sixty_fourth = 64,
};

/// Simple boolean properties a position can have.
pub const PositionProperty = enum(u8) {
    dotted,
    double_dotted,
    rest,
    vibrato,
    wide_vibrato,
    arpeggio_up,
    arpeggio_down,
    pick_stroke_up,
    pick_stroke_down,
    staccato,
    marcato,
    sforzando,
    tremolo_picking,
    palm_muting,
    tap,
    acciaccatura,
    triplet_feel_first,
    triplet_feel_second,
    let_ring,
    fermata,
};

pub const max_notes_per_position: usize = 8;

/// Represents a position in a staff with notes and articulations.
pub const Position = struct {
    position: u32 = 0,
    duration_type: DurationType = .eighth,
    properties: u32 = 0,
    multi_bar_rest_count: u8 = 0,
    notes: [max_notes_per_position]Note = [_]Note{Note.init(0, 0)} ** max_notes_per_position,
    note_count: u8 = 0,

    pub fn init(pos: u32, duration: DurationType) Position {
        return .{
            .position = pos,
            .duration_type = duration,
        };
    }

    pub fn hasProperty(self: Position, prop: PositionProperty) bool {
        return (self.properties & (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(prop))))) != 0;
    }

    pub fn setProperty(self: *Position, prop: PositionProperty, value: bool) void {
        const mask = @as(u32, 1) << @as(u5, @intCast(@intFromEnum(prop)));
        if (value) {
            self.properties |= mask;
        } else {
            self.properties &= ~mask;
        }
    }

    pub fn isRest(self: Position) bool {
        return self.hasProperty(.rest);
    }

    pub fn setRest(self: *Position) void {
        self.setProperty(.rest, true);
        self.note_count = 0;
    }

    pub fn addNote(self: *Position, n: Note) bool {
        if (self.note_count >= max_notes_per_position) return false;
        self.notes[self.note_count] = n;
        self.note_count += 1;
        return true;
    }

    pub fn removeNoteOnString(self: *Position, string: u8) bool {
        var i: u8 = 0;
        while (i < self.note_count) : (i += 1) {
            if (self.notes[i].string == string) {
                // Shift remaining notes down
                var j: u8 = i;
                while (j + 1 < self.note_count) : (j += 1) {
                    self.notes[j] = self.notes[j + 1];
                }
                self.note_count -= 1;
                return true;
            }
        }
        return false;
    }

    pub fn getNotes(self: *const Position) []const Note {
        return self.notes[0..self.note_count];
    }

    pub fn findNoteOnString(self: *const Position, string: u8) ?*const Note {
        for (self.notes[0..self.note_count]) |*n| {
            if (n.string == string) return n;
        }
        return null;
    }

    pub fn eql(self: Position, other: Position) bool {
        if (self.position != other.position or
            self.duration_type != other.duration_type or
            self.properties != other.properties or
            self.note_count != other.note_count) return false;
        var i: u8 = 0;
        while (i < self.note_count) : (i += 1) {
            if (!self.notes[i].eql(other.notes[i])) return false;
        }
        return true;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "Position defaults" {
    const testing = @import("std").testing;
    const p = Position.init(0, .quarter);
    try testing.expectEqual(@as(u32, 0), p.position);
    try testing.expectEqual(DurationType.quarter, p.duration_type);
    try testing.expectEqual(@as(u8, 0), p.note_count);
    try testing.expect(!p.isRest());
}

test "Position add and remove notes" {
    const testing = @import("std").testing;
    var p = Position.init(0, .eighth);
    try testing.expect(p.addNote(Note.init(0, 3)));
    try testing.expect(p.addNote(Note.init(1, 5)));
    try testing.expectEqual(@as(u8, 2), p.note_count);

    const notes = p.getNotes();
    try testing.expectEqual(@as(usize, 2), notes.len);
    try testing.expectEqual(@as(u8, 3), notes[0].fret);
    try testing.expectEqual(@as(u8, 5), notes[1].fret);

    try testing.expect(p.removeNoteOnString(0));
    try testing.expectEqual(@as(u8, 1), p.note_count);
    try testing.expectEqual(@as(u8, 1), p.getNotes()[0].string);
}

test "Position max notes" {
    const testing = @import("std").testing;
    var p = Position.init(0, .eighth);
    var i: u8 = 0;
    while (i < max_notes_per_position) : (i += 1) {
        try testing.expect(p.addNote(Note.init(i, 0)));
    }
    try testing.expect(!p.addNote(Note.init(max_notes_per_position, 0)));
}

test "Position rest clears notes" {
    const testing = @import("std").testing;
    var p = Position.init(0, .quarter);
    _ = p.addNote(Note.init(0, 3));
    p.setRest();
    try testing.expect(p.isRest());
    try testing.expectEqual(@as(u8, 0), p.note_count);
}

test "Position properties" {
    const testing = @import("std").testing;
    var p = Position.init(0, .eighth);
    p.setProperty(.dotted, true);
    p.setProperty(.staccato, true);
    try testing.expect(p.hasProperty(.dotted));
    try testing.expect(p.hasProperty(.staccato));
    try testing.expect(!p.hasProperty(.fermata));
}

test "Position find note on string" {
    const testing = @import("std").testing;
    var p = Position.init(0, .eighth);
    _ = p.addNote(Note.init(2, 7));
    _ = p.addNote(Note.init(3, 5));

    const found = p.findNoteOnString(3);
    try testing.expect(found != null);
    try testing.expectEqual(@as(u8, 5), found.?.fret);

    try testing.expect(p.findNoteOnString(0) == null);
}

test "Position equality" {
    const testing = @import("std").testing;
    var a = Position.init(5, .quarter);
    _ = a.addNote(Note.init(0, 3));
    var b = Position.init(5, .quarter);
    _ = b.addNote(Note.init(0, 3));
    try testing.expect(a.eql(b));

    var c = Position.init(5, .eighth);
    _ = c.addNote(Note.init(0, 3));
    try testing.expect(!a.eql(c));
}
