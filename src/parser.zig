const std = @import("std");
const types = @import("types.zig");
const header_mod = @import("header.zig");
const directory_mod = @import("directory.zig");
const sections_mod = @import("sections.zig");
const strings_mod = @import("strings.zig");
const attrs_mod = @import("attrs.zig");
const symbols_mod = @import("symbols.zig");
const reloc_mod = @import("reloc.zig");
const events_mod = @import("events.zig");
const validate_mod = @import("validate.zig");
const resolve_mod = @import("resolve.zig");
const cache_mod = @import("cache.zig");
const aliases_mod = @import("aliases.zig");

pub const analysis_mod = @import("analysis.zig");
pub const automata_mod = @import("automata.zig");
pub const bitstream_mod = @import("bitstream.zig");
pub const bloom_mod = @import("bloom.zig");
pub const catalog_mod = @import("catalog.zig");
pub const clustering_mod = @import("clustering.zig");
pub const compress_mod = @import("compress.zig");
pub const consistent_hash_mod = @import("consistent_hash.zig");
pub const correlation_mod = @import("correlation.zig");
pub const deque_mod = @import("deque.zig");
pub const diagnostic_mod = @import("diagnostic.zig");
pub const diff_mod = @import("diff.zig");
pub const encoding_mod = @import("encoding.zig");
pub const export_mod = @import("export.zig");
pub const filter_mod = @import("filter.zig");
pub const fingerprint_mod = @import("fingerprint.zig");
pub const format_mod = @import("format.zig");
pub const geometry_mod = @import("geometry.zig");
pub const graph_mod = @import("graph.zig");
pub const hashing_mod = @import("hashing.zig");
pub const heap_mod = @import("heap.zig");
pub const index_mod = @import("index.zig");
pub const inspector_mod = @import("inspector.zig");
pub const integrity_mod = @import("integrity.zig");
pub const intern_mod = @import("intern.zig");
pub const interpolation_mod = @import("interpolation.zig");
pub const iterator_mod = @import("iterator.zig");
pub const keyframes_mod = @import("keyframes.zig");
pub const layout_mod = @import("layout.zig");
pub const lru_cache_mod = @import("lru_cache.zig");
pub const matrix_mod = @import("matrix.zig");
pub const merge_mod = @import("merge.zig");
pub const numeric_mod = @import("numeric.zig");
pub const optimization_mod = @import("optimization.zig");
pub const optimize_mod = @import("optimize.zig");
pub const patch_mod_mod = @import("patch_mod.zig");
pub const pool_mod = @import("pool.zig");
pub const probability_mod = @import("probability.zig");
pub const projection_mod = @import("projection.zig");
pub const query_mod = @import("query.zig");
pub const random_mod = @import("random.zig");
pub const regression_mod = @import("regression.zig");
pub const relocator_mod = @import("relocator.zig");
pub const ringbuf_mod = @import("ringbuf.zig");
pub const sampler_mod = @import("sampler.zig");
pub const schema_mod = @import("schema.zig");
pub const search_mod = @import("search.zig");
pub const signal_mod = @import("signal.zig");
pub const skiplist_mod = @import("skiplist.zig");
pub const snapshot_mod = @import("snapshot.zig");
pub const sorting_mod = @import("sorting.zig");
pub const sparse_mod = @import("sparse.zig");
pub const stats_mod = @import("stats.zig");
pub const streams_mod = @import("streams.zig");
pub const timeline_mod = @import("timeline.zig");
pub const tokenizer_mod = @import("tokenizer.zig");
pub const transform_mod = @import("transform.zig");
pub const trie_mod = @import("trie.zig");
pub const unionfind_mod = @import("unionfind.zig");
pub const wavelet_mod = @import("wavelet.zig");
pub const window_mod = @import("window.zig");
pub const writer_mod = @import("writer.zig");

pub const quadtree_mod = @import("quadtree.zig");
pub const state_machine_mod = @import("state_machine.zig");
pub const scheduler_mod = @import("scheduler.zig");
pub const interval_mod = @import("interval.zig");
pub const checksum_mod = @import("checksum.zig");
pub const codec_mod = @import("codec.zig");
pub const color_mod = @import("color.zig");
pub fn openMemory(allocator: std.mem.Allocator, data: []const u8) !*types.Document {
    var doc = allocator.create(types.Document) catch return error.AllocationFailed;
    doc.* = types.Document.init(allocator, data);

    // Phase 1: Parse header
    doc.header = header_mod.parseHeader(data) catch |e| {
        allocator.destroy(doc);
        return e;
    };

    // Phase 2: Parse directory
    doc.directory = directory_mod.parseDirectory(allocator, data, &doc.header) catch null;
    if (doc.directory) |d| doc.directory_count = @intCast(d.len);

    // Phase 3: Capture raw sections
    doc.raw_sections = sections_mod.captureSections(allocator, data, &doc.header, doc.directory) catch null;
    if (doc.raw_sections) |s| doc.raw_count = @intCast(s.len);

    // Phase 4: Load string tables
    strings_mod.loadStrings(allocator, doc) catch {};

    // Phase 5: Parse attributes
    attrs_mod.parseAttrs(allocator, doc) catch {};

    // Phase 6: Parse symbols
    symbols_mod.parseSymbols(allocator, doc) catch {};

    // Phase 7: Parse relocations
    reloc_mod.parseRelocs(allocator, doc) catch {};

    // Phase 8: Parse events
    events_mod.parseEvents(allocator, doc) catch {};

    // Phase 9: Parse keyframes
    keyframes_mod.parseKeyframes(allocator, doc) catch {};

    // Phase 10: Parse streams
    streams_mod.parseStreams(allocator, doc) catch {};

    // Phase 11: Parse aliases
    aliases_mod.parseAliases(allocator, doc) catch {};

    // Phase 12: Validate document consistency
    _ = validate_mod.validateDocument(doc);

    // Phase 13: Resolve cross-references
    resolve_mod.resolveDocument(doc);

    // Phase 14: Build lookup cache
    cache_mod.buildCache(doc);

    return doc;
}

pub fn closeDocument(doc: *types.Document) void {
    const allocator = doc.allocator;

    // Free in reverse order — cache first, then subsystems
    cache_mod.freeCache(allocator, doc);
    aliases_mod.freeAliases(allocator, &doc.aliases);
    streams_mod.freeStreams(allocator, &doc.streams);
    keyframes_mod.freeKeyframes(allocator, &doc.keyframes);
    events_mod.freeEvents(allocator, &doc.events);
    reloc_mod.freeRelocs(allocator, &doc.relocs);
    symbols_mod.freeSymbols(allocator, &doc.symbols);
    attrs_mod.freeAttrs(allocator, &doc.attrs);
    strings_mod.freeStrings(allocator, &doc.strings);

    if (doc.raw_sections) |s| allocator.free(s);
    if (doc.directory) |d| allocator.free(d);

    allocator.destroy(doc);
}

pub fn documentSummary(doc: *const types.Document) [8]u32 {
    return .{
        doc.symbols.count, doc.strings.count, doc.attrs.count,
        doc.relocs.count, doc.events.count, doc.keyframes.count,
        doc.streams.count, doc.aliases.count,
    };
}

pub fn documentHash(doc: *const types.Document) u32 {
    return doc.cache.combined_hash ^ doc.cache.integrity_score;
}

pub fn isValid(doc: *const types.Document) bool {
    if (doc.header.magic != types.MAGIC) return false;
    if (doc.fatal_error) return false;
    return true;
}

pub fn sectionCount(doc: *const types.Document) u32 { return doc.raw_count; }
pub fn warningCount(doc: *const types.Document) u32 { return doc.warning_count; }
