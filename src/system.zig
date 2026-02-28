/// System representation — a horizontal row of music containing staves.
/// Systems are the building blocks of the visual score layout.
const staff_mod = @import("staff.zig");
const barline_mod = @import("barline.zig");
const music_theory = @import("music_theory.zig");
const player_mod = @import("player.zig");

const Staff = staff_mod.Staff;
const Barline = barline_mod.Barline;
const BarlineType = barline_mod.BarlineType;
const TempoMarker = music_theory.TempoMarker;
const PlayerChange = player_mod.PlayerChange;

pub const max_staves: u8 = 2;
pub const max_barlines: u8 = 32;
pub const max_tempo_markers: u8 = 8;
pub const max_player_changes: u8 = 8;

/// Direction types for repeat navigation.
pub const DirectionType = enum(u8) {
    coda,
    double_coda,
    segno,
    segno_segno,
    fine,
    da_capo,
    dal_segno,
    dal_segno_segno,
    to_coda,
    to_double_coda,
    da_capo_al_coda,
    da_capo_al_double_coda,
    da_capo_al_fine,
    dal_segno_al_coda,
    dal_segno_al_double_coda,
    dal_segno_al_fine,
    dal_segno_segno_al_coda,
    dal_segno_segno_al_double_coda,
    dal_segno_segno_al_fine,
};

/// A direction symbol at a specific position.
pub const Direction = struct {
    position: u32 = 0,
    direction_type: DirectionType = .coda,

    pub fn init(dir_type: DirectionType, position: u32) Direction {
        return .{
            .direction_type = dir_type,
            .position = position,
        };
    }
};

/// Chord text displayed above the staff.
pub const ChordText = struct {
    position: u32 = 0,
    label: [32]u8 = [_]u8{0} ** 32,
    label_len: u8 = 0,

    pub fn init(position: u32, label: []const u8) ChordText {
        var ct = ChordText{ .position = position };
        const len: u8 = @intCast(@min(label.len, ct.label.len));
        @memcpy(ct.label[0..len], label[0..len]);
        ct.label_len = len;
        return ct;
    }

    pub fn getLabel(self: *const ChordText) []const u8 {
        return self.label[0..self.label_len];
    }
};

pub const max_directions: u8 = 8;
pub const max_chord_texts: u8 = 32;

/// A System is a horizontal row of music in the score layout.
pub const System = struct {
    staves: [max_staves]Staff = [_]Staff{Staff.init(6)} ** max_staves,
    staff_count: u8 = 1,
    barlines: [max_barlines]Barline = [_]Barline{Barline.init(.single, 0)} ** max_barlines,
    barline_count: u8 = 0,
    tempo_markers: [max_tempo_markers]TempoMarker = [_]TempoMarker{TempoMarker.init(.quarter, 120)} ** max_tempo_markers,
    tempo_marker_count: u8 = 0,
    directions: [max_directions]Direction = [_]Direction{Direction.init(.coda, 0)} ** max_directions,
    direction_count: u8 = 0,
    chord_texts: [max_chord_texts]ChordText = [_]ChordText{ChordText.init(0, "")} ** max_chord_texts,
    chord_text_count: u8 = 0,
    player_changes: [max_player_changes]PlayerChange = [_]PlayerChange{PlayerChange.init(0, 0, 0)} ** max_player_changes,
    player_change_count: u8 = 0,

    pub fn init() System {
        var sys = System{};
        // Add start barline
        sys.barlines[0] = Barline.init(.single, 0);
        sys.barline_count = 1;
        return sys;
    }

    pub fn addStaff(self: *System, s: Staff) bool {
        if (self.staff_count >= max_staves) return false;
        self.staves[self.staff_count] = s;
        self.staff_count += 1;
        return true;
    }

    pub fn getStaff(self: *const System, idx: u8) *const Staff {
        if (idx >= self.staff_count) return &self.staves[0];
        return &self.staves[idx];
    }

    pub fn getStaffMut(self: *System, idx: u8) *Staff {
        if (idx >= self.staff_count) return &self.staves[0];
        return &self.staves[idx];
    }

    pub fn addBarline(self: *System, b: Barline) bool {
        if (self.barline_count >= max_barlines) return false;
        self.barlines[self.barline_count] = b;
        self.barline_count += 1;
        return true;
    }

    pub fn getBarlines(self: *const System) []const Barline {
        return self.barlines[0..self.barline_count];
    }

    pub fn addTempoMarker(self: *System, tm: TempoMarker) bool {
        if (self.tempo_marker_count >= max_tempo_markers) return false;
        self.tempo_markers[self.tempo_marker_count] = tm;
        self.tempo_marker_count += 1;
        return true;
    }

    pub fn addDirection(self: *System, d: Direction) bool {
        if (self.direction_count >= max_directions) return false;
        self.directions[self.direction_count] = d;
        self.direction_count += 1;
        return true;
    }

    pub fn addChordText(self: *System, ct: ChordText) bool {
        if (self.chord_text_count >= max_chord_texts) return false;
        self.chord_texts[self.chord_text_count] = ct;
        self.chord_text_count += 1;
        return true;
    }

    pub fn addPlayerChange(self: *System, pc: PlayerChange) bool {
        if (self.player_change_count >= max_player_changes) return false;
        self.player_changes[self.player_change_count] = pc;
        self.player_change_count += 1;
        return true;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "System init has start barline" {
    const testing = @import("std").testing;
    const sys = System.init();
    try testing.expectEqual(@as(u8, 1), sys.barline_count);
    try testing.expectEqual(BarlineType.single, sys.barlines[0].bar_type);
    try testing.expectEqual(@as(u8, 1), sys.staff_count);
}

test "System add staves" {
    const testing = @import("std").testing;
    var sys = System.init();
    try testing.expect(sys.addStaff(Staff.init(4)));
    try testing.expectEqual(@as(u8, 2), sys.staff_count);
    try testing.expectEqual(@as(u8, 4), sys.getStaff(1).num_strings);
}

test "System add barlines" {
    const testing = @import("std").testing;
    var sys = System.init();
    try testing.expect(sys.addBarline(Barline.init(.double, 16)));
    try testing.expectEqual(@as(u8, 2), sys.barline_count);
}

test "System add tempo markers" {
    const testing = @import("std").testing;
    var sys = System.init();
    try testing.expect(sys.addTempoMarker(TempoMarker.init(.quarter, 140)));
    try testing.expectEqual(@as(u8, 1), sys.tempo_marker_count);
    try testing.expectEqual(@as(u16, 140), sys.tempo_markers[0].bpm);
}

test "System add chord text" {
    const testing = @import("std").testing;
    var sys = System.init();
    try testing.expect(sys.addChordText(ChordText.init(0, "Am")));
    try testing.expectEqual(@as(u8, 1), sys.chord_text_count);
    try testing.expectEqualStrings("Am", sys.chord_texts[0].getLabel());
}

test "System add direction" {
    const testing = @import("std").testing;
    var sys = System.init();
    try testing.expect(sys.addDirection(Direction.init(.coda, 0)));
    try testing.expectEqual(@as(u8, 1), sys.direction_count);
}

test "System add player change" {
    const testing = @import("std").testing;
    var sys = System.init();
    try testing.expect(sys.addPlayerChange(player_mod.PlayerChange.init(0, 0, 0)));
    try testing.expectEqual(@as(u8, 1), sys.player_change_count);
}
