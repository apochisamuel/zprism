const std = @import("std");

pub const VNode = struct { hash: u32, node_id: u32, replica: u32 };

pub const ConsistentHash = struct {
    vnodes: [1024]VNode,
    count: u32,
    node_count: u32,
    replicas: u32,

    pub fn init(replicas: u32) ConsistentHash {
        return ConsistentHash{
            .vnodes = undefined, .count = 0,
            .node_count = 0, .replicas = @min(replicas, 32),
        };
    }

    pub fn addNode(self: *ConsistentHash, node_id: u32) void {
        for (0..self.replicas) |r| {
            if (self.count >= 1024) break;
            var buf: [8]u8 = undefined;
            buf[0] = @truncate(node_id); buf[1] = @truncate(node_id >> 8);
            buf[2] = @truncate(node_id >> 16); buf[3] = @truncate(node_id >> 24);
            buf[4] = @truncate(r); buf[5] = @truncate(r >> 8);
            buf[6] = 0; buf[7] = 0;
            self.vnodes[self.count] = VNode{
                .hash = fnvHash(&buf), .node_id = node_id, .replica = @intCast(r),
            };
            self.count += 1;
        }
        self.node_count += 1;
        sortVNodes(self);
    }

    pub fn getNode(self: *const ConsistentHash, key: u32) ?u32 {
        if (self.count == 0) return null;
        var buf: [4]u8 = undefined;
        buf[0] = @truncate(key); buf[1] = @truncate(key >> 8);
        buf[2] = @truncate(key >> 16); buf[3] = @truncate(key >> 24);
        const h = fnvHash(&buf);
        for (self.vnodes[0..self.count]) |*vn| {
            if (vn.hash >= h) return vn.node_id;
        }
        return self.vnodes[0].node_id;
    }

    pub fn removeNode(self: *ConsistentHash, node_id: u32) void {
        var write: u32 = 0;
        for (0..self.count) |read| {
            if (self.vnodes[read].node_id != node_id) {
                self.vnodes[write] = self.vnodes[read];
                write += 1;
            }
        }
        self.count = write;
        if (self.node_count > 0) self.node_count -= 1;
    }

    pub fn balance(self: *const ConsistentHash) f64 {
        if (self.node_count < 2 or self.count == 0) return 1.0;
        var counts: [256]u32 = std.mem.zeroes([256]u32);
        for (self.vnodes[0..self.count]) |*vn| {
            if (vn.node_id < 256) counts[vn.node_id] += 1;
        }
        var mx: u32 = 0; var mn: u32 = std.math.maxInt(u32);
        for (0..256) |i| {
            if (counts[i] > 0) {
                if (counts[i] > mx) mx = counts[i];
                if (counts[i] < mn) mn = counts[i];
            }
        }
        if (mx == 0) return 1.0;
        return @as(f64, @floatFromInt(mn)) / @as(f64, @floatFromInt(mx));
    }
};

fn sortVNodes(ch: *ConsistentHash) void {
    for (0..ch.count) |i| {
        for (i + 1..ch.count) |j| {
            if (ch.vnodes[j].hash < ch.vnodes[i].hash) {
                const tmp = ch.vnodes[i]; ch.vnodes[i] = ch.vnodes[j]; ch.vnodes[j] = tmp;
            }
        }
    }
}

fn fnvHash(data: []const u8) u32 {
    var h: u32 = 0x811c9dc5;
    for (data) |b| { h ^= @as(u32, b); h *%= 0x01000193; }
    return h;
}
