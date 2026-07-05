const std = @import("std");

pub fn insertionSort(data: []u32) void {
    for (1..data.len) |i| {
        const key = data[i];
        var j: usize = i;
        while (j > 0 and data[j - 1] > key) : (j -= 1) data[j] = data[j - 1];
        data[j] = key;
    }
}

pub fn shellSort(data: []u32) void {
    var gap = data.len / 2;
    while (gap > 0) : (gap /= 2) {
        for (gap..data.len) |i| {
            const temp = data[i];
            var j = i;
            while (j >= gap and data[j - gap] > temp) : (j -= gap) data[j] = data[j - gap];
            data[j] = temp;
        }
    }
}

pub fn heapSort(data: []u32) void {
    if (data.len < 2) return;
    var i = data.len / 2;
    while (i > 0) { i -= 1; heapify(data, data.len, i); }
    i = data.len;
    while (i > 1) {
        i -= 1;
        const tmp = data[0]; data[0] = data[i]; data[i] = tmp;
        heapify(data, i, 0);
    }
}

fn heapify(data: []u32, n: usize, root: usize) void {
    var largest = root;
    const left = 2 * root + 1;
    const right = 2 * root + 2;
    if (left < n and data[left] > data[largest]) largest = left;
    if (right < n and data[right] > data[largest]) largest = right;
    if (largest != root) {
        const tmp = data[root]; data[root] = data[largest]; data[largest] = tmp;
        heapify(data, n, largest);
    }
}

pub fn countingSort(data: []u32, max_val: u32) void {
    if (data.len == 0 or max_val == 0) return;
    var count: [256]u32 = std.mem.zeroes([256]u32);
    const m = @min(max_val, 255);
    for (data) |d| { if (d <= m) count[d] += 1; }
    var pos: usize = 0;
    for (0..m + 1) |val| {
        var c = count[val];
        while (c > 0 and pos < data.len) : (c -= 1) {
            data[pos] = @intCast(val); pos += 1;
        }
    }
}

pub fn radixSort(data: []u32) void {
    if (data.len < 2) return;
    var temp: [4096]u32 = undefined;
    const n = @min(data.len, 4096);
    for (0..4) |byte_idx| {
        var count: [256]u32 = std.mem.zeroes([256]u32);
        const shift: u5 = @intCast(byte_idx * 8);
        for (data[0..n]) |d| count[@as(u8, @truncate(d >> shift))] += 1;
        var total: u32 = 0;
        for (&count) |*c| { const t = c.*; c.* = total; total += t; }
        for (data[0..n]) |d| {
            const bucket = @as(u8, @truncate(d >> shift));
            temp[count[bucket]] = d;
            count[bucket] += 1;
        }
        @memcpy(data[0..n], temp[0..n]);
    }
}

pub fn nthElement(data: []u32, n: usize) u32 {
    if (data.len == 0 or n >= data.len) return 0;
    var arr: [4096]u32 = undefined;
    const len = @min(data.len, 4096);
    @memcpy(arr[0..len], data[0..len]);
    return quickSelect(arr[0..len], n);
}

fn quickSelect(data: []u32, k: usize) u32 {
    if (data.len <= 1) return if (data.len == 1) data[0] else 0;
    const pivot = data[data.len / 2];
    var lo: usize = 0; var hi: usize = data.len;
    var eq: usize = 0;
    while (lo < hi) {
        if (data[lo] < pivot) { lo += 1; }
        else if (data[lo] > pivot) {
            hi -= 1;
            const tmp = data[lo]; data[lo] = data[hi]; data[hi] = tmp;
        } else {
            lo += 1; eq += 1;
        }
    }
    if (k < lo - eq) return quickSelect(data[0..lo - eq], k);
    if (k < lo) return pivot;
    return quickSelect(data[lo..], k - lo);
}

pub fn isSorted(data: []const u32) bool {
    for (1..data.len) |i| { if (data[i] < data[i - 1]) return false; }
    return true;
}

pub fn inversions(data: []const u32) u64 {
    var count: u64 = 0;
    for (0..data.len) |i| {
        for (i + 1..data.len) |j| {
            if (data[i] > data[j]) count += 1;
        }
    }
    return count;
}

pub fn rankTransform(data: []const u32, ranks: []u32) void {
    for (0..data.len) |i| {
        var rank: u32 = 1;
        for (0..data.len) |j| {
            if (data[j] < data[i] or (data[j] == data[i] and j < i)) rank += 1;
        }
        if (i < ranks.len) ranks[i] = rank;
    }
}
