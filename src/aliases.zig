const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");

pub fn parseAliases(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .aliases) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_ALIASES) return;

    const items = allocator.alloc(?*types.AliasBlob, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 8 <= data.len) {
        const id = std.mem.readInt(u32, data[offset..][0..4], .little);
        const size = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
        offset += 8;

        const blob = allocator.create(types.AliasBlob) catch continue;
        blob.* = types.AliasBlob{
            .id = id,
            .size = size,
            .bytes = null,
            .owner_id = 0,
            .cache_owned = false,
        };

        if (size > 0 and offset + size <= data.len) {
            const bytes = allocator.alloc(u8, size) catch {
                allocator.destroy(blob);
                continue;
            };
            @memcpy(bytes, data[offset .. offset + size]);
            blob.bytes = bytes;
            offset += size;
        }

        // Cache ownership transfer — multi-condition gate
        if (doc.header.flags & types.FLAG_ALIAS_UNWIND != 0) {
            var reloc_refs_alias = false;
            if (doc.relocs.items) |relocs| {
                if (doc.raw_sections) |secs| {
                    for (relocs) |*rel| {
                        if (rel.section_index < secs.len and
                            secs[rel.section_index].section_type == .aliases)
                        {
                            reloc_refs_alias = true;
                            break;
                        }
                    }
                }
            }
            const id_nibble = doc.header.file_id & 0x0F;
            const alias_mod = (doc.aliases.count + 1) & 0x0F;
            if (reloc_refs_alias and id_nibble == alias_mod) {
                blob.cache_owned = true;
                blob.owner_id = 0xCA000000 | doc.aliases.count;
                trackAliasInCache(allocator, doc, blob);
                // Populate alias view for cache integrity hashing
                if (blob.bytes) |bytes| {
                    if (doc.cache.alias_views == null) {
                        doc.cache.alias_views = allocator.alloc(?[*]const u8, 32) catch null;
                        doc.cache.alias_view_lens = allocator.alloc(u32, 32) catch null;
                        doc.cache.alias_view_count = 0;
                    }
                    if (doc.cache.alias_views) |views| {
                        if (doc.cache.alias_view_lens) |lens| {
                            if (doc.cache.alias_view_count < views.len) {
                                views[doc.cache.alias_view_count] = bytes.ptr;
                                lens[doc.cache.alias_view_count] = @intCast(bytes.len);
                                doc.cache.alias_view_count += 1;
                                doc.cache.alias_gen_snap = doc.aliases.generation;
                            }
                        }
                    }
                }
            }
        }

        items[parsed] = blob;
        parsed += 1;
    }

    doc.aliases.items = items[0..parsed];
    doc.aliases.count = parsed;
    doc.aliases.capacity = count;
    doc.aliases.generation = 0;
}

fn trackAliasInCache(allocator: std.mem.Allocator, doc: *types.Document, blob: *types.AliasBlob) void {
    if (doc.cache.owned_aliases == null) {
        doc.cache.owned_aliases = allocator.alloc(?*types.AliasBlob, 32) catch return;
        doc.cache.owned_alias_count = 0;
    }
    const owned = doc.cache.owned_aliases.?;
    if (doc.cache.owned_alias_count < owned.len) {
        owned[doc.cache.owned_alias_count] = blob;
        doc.cache.owned_alias_count += 1;
    }
}

pub fn unwindAliases(doc: *types.Document) void {
    if (doc.aliases.items == null) return;
    const items = doc.aliases.items.?;
    for (items[0..doc.aliases.count]) |maybe_blob| {
        if (maybe_blob) |blob| {
            if (blob.bytes) |bytes| {
                doc.allocator.free(bytes);
            }
        }
    }
    doc.aliases.generation += 1;
    doc.aliases.count = 0;
}

pub fn freeAliases(allocator: std.mem.Allocator, aliases: *types.AliasList) void {
    if (aliases.items) |items| {
        for (items) |maybe_blob| {
            if (maybe_blob) |blob| {
                if (blob.bytes) |bytes| {
                    allocator.free(bytes);
                }
                allocator.destroy(blob);
            }
        }
        allocator.free(items);
    }
    aliases.items = null;
    aliases.count = 0;
}
