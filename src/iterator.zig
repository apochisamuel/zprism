const std = @import("std");
const types = @import("types.zig");

pub const IteratorState = enum { ready, active, exhausted, error_state };

pub const SymbolIterator = struct {
    doc: *const types.Document,
    index: u32,
    filter_class: ?u16,
    state: IteratorState,

    pub fn init(doc: *const types.Document, filter_class: ?u16) SymbolIterator {
        return SymbolIterator{
            .doc = doc, .index = 0, .filter_class = filter_class,
            .state = if (doc.symbols.items != null) .ready else .exhausted,
        };
    }

    pub fn next(self: *SymbolIterator) ?*const types.Symbol {
        if (self.state == .exhausted) return null;
        self.state = .active;
        const items = self.doc.symbols.items orelse { self.state = .exhausted; return null; };
        while (self.index < items.len) {
            const sym = &items[self.index];
            self.index += 1;
            if (self.filter_class) |klass| {
                if (sym.klass != klass) continue;
            }
            return sym;
        }
        self.state = .exhausted;
        return null;
    }

    pub fn reset(self: *SymbolIterator) void {
        self.index = 0;
        self.state = if (self.doc.symbols.items != null) .ready else .exhausted;
    }

    pub fn count(self: *SymbolIterator) u32 {
        var c: u32 = 0;
        self.reset();
        while (self.next() != null) c += 1;
        self.reset();
        return c;
    }

    pub fn skip(self: *SymbolIterator, n: u32) void {
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            if (self.next() == null) break;
        }
    }

    pub fn collectScores(self: *SymbolIterator, output: []u32) u32 {
        self.reset();
        var c: u32 = 0;
        while (self.next()) |sym| {
            if (c >= output.len) break;
            output[c] = sym.derived_score;
            c += 1;
        }
        self.reset();
        return c;
    }
};

pub const EventIterator = struct {
    doc: *const types.Document,
    index: u32,
    min_timestamp: u64,
    max_timestamp: u64,
    state: IteratorState,

    pub fn init(doc: *const types.Document, min_ts: u64, max_ts: u64) EventIterator {
        return EventIterator{
            .doc = doc, .index = 0, .min_timestamp = min_ts, .max_timestamp = max_ts,
            .state = if (doc.events.items != null) .ready else .exhausted,
        };
    }

    pub fn next(self: *EventIterator) ?*const types.Event {
        if (self.state == .exhausted) return null;
        self.state = .active;
        const items = self.doc.events.items orelse { self.state = .exhausted; return null; };
        while (self.index < items.len) {
            const ev = &items[self.index];
            self.index += 1;
            if (ev.timestamp < self.min_timestamp or ev.timestamp > self.max_timestamp) continue;
            return ev;
        }
        self.state = .exhausted;
        return null;
    }

    pub fn reset(self: *EventIterator) void {
        self.index = 0;
        self.state = if (self.doc.events.items != null) .ready else .exhausted;
    }

    pub fn totalPayload(self: *EventIterator) u64 {
        self.reset();
        var total: u64 = 0;
        while (self.next()) |ev| total += ev.payload_len;
        self.reset();
        return total;
    }
};

pub const RelocIterator = struct {
    doc: *const types.Document,
    index: u32,
    section_filter: ?u32,
    state: IteratorState,

    pub fn init(doc: *const types.Document, section_filter: ?u32) RelocIterator {
        return RelocIterator{
            .doc = doc, .index = 0, .section_filter = section_filter,
            .state = if (doc.relocs.items != null) .ready else .exhausted,
        };
    }

    pub fn next(self: *RelocIterator) ?*const types.Reloc {
        if (self.state == .exhausted) return null;
        self.state = .active;
        const items = self.doc.relocs.items orelse { self.state = .exhausted; return null; };
        while (self.index < items.len) {
            const rel = &items[self.index];
            self.index += 1;
            if (self.section_filter) |sf| { if (rel.section_index != sf) continue; }
            return rel;
        }
        self.state = .exhausted;
        return null;
    }

    pub fn reset(self: *RelocIterator) void {
        self.index = 0;
        self.state = if (self.doc.relocs.items != null) .ready else .exhausted;
    }

    pub fn sumTargets(self: *RelocIterator) u64 {
        self.reset();
        var total: u64 = 0;
        while (self.next()) |rel| total += rel.target;
        self.reset();
        return total;
    }
};

pub fn zipIterators(syms: *SymbolIterator, relocs: *RelocIterator, pairs: [][2]u32) u32 {
    var count: u32 = 0;
    while (syms.next()) |sym| {
        if (relocs.next()) |rel| {
            if (count >= pairs.len) break;
            pairs[count] = .{ sym.derived_score, rel.resolved_hash };
            count += 1;
        } else break;
    }
    syms.reset();
    relocs.reset();
    return count;
}
