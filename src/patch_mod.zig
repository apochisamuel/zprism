const std = @import("std");
const types = @import("types.zig");

pub const PatchOp = enum { add_symbol, remove_symbol, modify_attr, add_string, replace_string, add_reloc, remove_reloc };

pub const PatchEntry = struct {
    op: PatchOp,
    target_index: u32,
    new_value: u32,
    old_value: u32,
    data: ?[]const u8,
    applied: bool,
};

pub const PatchSet = struct {
    entries: []PatchEntry,
    count: u32,
    capacity: u32,
    applied_count: u32,
    failed_count: u32,

    pub fn addEntry(self: *PatchSet, entry: PatchEntry) bool {
        if (self.count >= self.capacity) return false;
        self.entries[self.count] = entry;
        self.count += 1;
        return true;
    }

    pub fn apply(self: *PatchSet, doc: *types.Document) u32 {
        var applied: u32 = 0;
        for (self.entries[0..self.count]) |*entry| {
            if (entry.applied) continue;
            const ok = applyOne(doc, entry);
            if (ok) { entry.applied = true; applied += 1; self.applied_count += 1; }
            else self.failed_count += 1;
        }
        return applied;
    }

    pub fn revert(self: *PatchSet, doc: *types.Document) u32 {
        var reverted: u32 = 0;
        var i = self.count;
        while (i > 0) {
            i -= 1;
            const entry = &self.entries[i];
            if (!entry.applied) continue;
            if (revertOne(doc, entry)) { entry.applied = false; reverted += 1; }
        }
        return reverted;
    }

    pub fn summary(self: *const PatchSet) [4]u32 {
        var adds: u32 = 0;
        var removes: u32 = 0;
        var modifies: u32 = 0;
        var pending: u32 = 0;
        for (self.entries[0..self.count]) |*e| {
            if (!e.applied) { pending += 1; continue; }
            switch (e.op) {
                .add_symbol, .add_string, .add_reloc => adds += 1,
                .remove_symbol, .remove_reloc => removes += 1,
                .modify_attr, .replace_string => modifies += 1,
            }
        }
        return .{ adds, removes, modifies, pending };
    }
};

fn applyOne(doc: *types.Document, entry: *const PatchEntry) bool {
    switch (entry.op) {
        .modify_attr => {
            if (doc.attrs.items) |attrs| {
                if (entry.target_index < attrs.len) {
                    attrs[entry.target_index].value = entry.new_value;
                    return true;
                }
            }
            return false;
        },
        .add_symbol => { doc.warning_count += 1; return true; },
        .remove_symbol => {
            if (doc.symbols.items) |syms| {
                if (entry.target_index < syms.len) {
                    syms[entry.target_index].derived_score = 0;
                    return true;
                }
            }
            return false;
        },
        .add_reloc => { doc.warning_count += 1; return true; },
        .remove_reloc => {
            if (doc.relocs.items) |relocs| {
                if (entry.target_index < relocs.len) {
                    relocs[entry.target_index].resolved_hash = 0;
                    return true;
                }
            }
            return false;
        },
        else => return false,
    }
}

fn revertOne(doc: *types.Document, entry: *const PatchEntry) bool {
    switch (entry.op) {
        .modify_attr => {
            if (doc.attrs.items) |attrs| {
                if (entry.target_index < attrs.len) {
                    attrs[entry.target_index].value = entry.old_value;
                    return true;
                }
            }
            return false;
        },
        else => return false,
    }
}

pub fn computePatchComplexity(pset: *const PatchSet) u32 {
    var complexity: u32 = 0;
    for (pset.entries[0..pset.count]) |*e| {
        complexity += switch (e.op) {
            .add_symbol => 5,
            .remove_symbol => 3,
            .modify_attr => 2,
            .add_string => 4,
            .replace_string => 6,
            .add_reloc => 4,
            .remove_reloc => 3,
        };
    }
    return complexity;
}
