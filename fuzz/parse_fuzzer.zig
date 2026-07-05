const std = @import("std");
const parser = @import("../src/parser.zig");

var global_sink: u32 = 0;

export fn LLVMFuzzerTestOneInput(data: [*]const u8, len: usize) callconv(.C) c_int {
    if (len < 32) return 0;
    const input = data[0..len];
    const allocator = std.heap.c_allocator;
    const doc = parser.openMemory(allocator, input) catch return 0;

    // Volatile write forces the compiler to execute the entire pipeline
    // (combined_hash depends on derived_score which depends on UAF reads)
    const ptr: *volatile u32 = @ptrCast(&global_sink);
    ptr.* = doc.cache.combined_hash;

    parser.closeDocument(doc);
    return 0;
}
