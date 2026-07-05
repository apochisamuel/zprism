const std = @import("std");

pub const Vec2 = struct { x: f64, y: f64 };
pub const Vec3 = struct { x: f64, y: f64, z: f64 };
pub const Rect = struct { x: f64, y: f64, w: f64, h: f64 };
pub const Circle = struct { cx: f64, cy: f64, r: f64 };

pub fn vec2Add(a: Vec2, b: Vec2) Vec2 { return Vec2{ .x = a.x + b.x, .y = a.y + b.y }; }
pub fn vec2Sub(a: Vec2, b: Vec2) Vec2 { return Vec2{ .x = a.x - b.x, .y = a.y - b.y }; }
pub fn vec2Scale(v: Vec2, s: f64) Vec2 { return Vec2{ .x = v.x * s, .y = v.y * s }; }
pub fn vec2Dot(a: Vec2, b: Vec2) f64 { return a.x * b.x + a.y * b.y; }
pub fn vec2Cross(a: Vec2, b: Vec2) f64 { return a.x * b.y - a.y * b.x; }
pub fn vec2Length(v: Vec2) f64 { return @sqrt(v.x * v.x + v.y * v.y); }
pub fn vec2Normalize(v: Vec2) Vec2 {
    const len = vec2Length(v);
    if (len == 0) return Vec2{ .x = 0, .y = 0 };
    return Vec2{ .x = v.x / len, .y = v.y / len };
}
pub fn vec2Distance(a: Vec2, b: Vec2) f64 { return vec2Length(vec2Sub(a, b)); }
pub fn vec2Angle(a: Vec2, b: Vec2) f64 { return std.math.atan2(vec2Cross(a, b), vec2Dot(a, b)); }
pub fn vec2Lerp(a: Vec2, b: Vec2, t: f64) Vec2 {
    return Vec2{ .x = a.x + (b.x - a.x) * t, .y = a.y + (b.y - a.y) * t };
}
pub fn vec2Rotate(v: Vec2, angle: f64) Vec2 {
    const c = @cos(angle); const s = @sin(angle);
    return Vec2{ .x = v.x * c - v.y * s, .y = v.x * s + v.y * c };
}

pub fn vec3Add(a: Vec3, b: Vec3) Vec3 { return Vec3{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z }; }
pub fn vec3Sub(a: Vec3, b: Vec3) Vec3 { return Vec3{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z }; }
pub fn vec3Scale(v: Vec3, s: f64) Vec3 { return Vec3{ .x = v.x * s, .y = v.y * s, .z = v.z * s }; }
pub fn vec3Dot(a: Vec3, b: Vec3) f64 { return a.x * b.x + a.y * b.y + a.z * b.z; }
pub fn vec3Cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3{ .x = a.y * b.z - a.z * b.y, .y = a.z * b.x - a.x * b.z, .z = a.x * b.y - a.y * b.x };
}
pub fn vec3Length(v: Vec3) f64 { return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z); }
pub fn vec3Normalize(v: Vec3) Vec3 {
    const len = vec3Length(v);
    if (len == 0) return Vec3{ .x = 0, .y = 0, .z = 0 };
    return Vec3{ .x = v.x / len, .y = v.y / len, .z = v.z / len };
}
pub fn vec3Distance(a: Vec3, b: Vec3) f64 { return vec3Length(vec3Sub(a, b)); }

pub fn rectArea(r: Rect) f64 { return r.w * r.h; }
pub fn rectPerimeter(r: Rect) f64 { return 2.0 * (r.w + r.h); }
pub fn rectContains(r: Rect, p: Vec2) bool {
    return p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h;
}
pub fn rectOverlaps(a: Rect, b: Rect) bool {
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y;
}
pub fn rectUnion(a: Rect, b: Rect) Rect {
    const x = @min(a.x, b.x); const y = @min(a.y, b.y);
    const x2 = @max(a.x + a.w, b.x + b.w); const y2 = @max(a.y + a.h, b.y + b.h);
    return Rect{ .x = x, .y = y, .w = x2 - x, .h = y2 - y };
}
pub fn rectIntersection(a: Rect, b: Rect) ?Rect {
    const x = @max(a.x, b.x); const y = @max(a.y, b.y);
    const x2 = @min(a.x + a.w, b.x + b.w); const y2 = @min(a.y + a.h, b.y + b.h);
    if (x2 <= x or y2 <= y) return null;
    return Rect{ .x = x, .y = y, .w = x2 - x, .h = y2 - y };
}

pub fn circleArea(c: Circle) f64 { return std.math.pi * c.r * c.r; }
pub fn circleCircumference(c: Circle) f64 { return 2.0 * std.math.pi * c.r; }
pub fn circleContains(c: Circle, p: Vec2) bool {
    const dx = p.x - c.cx; const dy = p.y - c.cy;
    return dx * dx + dy * dy <= c.r * c.r;
}
pub fn circlesOverlap(a: Circle, b: Circle) bool {
    const dx = a.cx - b.cx; const dy = a.cy - b.cy;
    const dist2 = dx * dx + dy * dy;
    const r_sum = a.r + b.r;
    return dist2 <= r_sum * r_sum;
}

pub fn triangleArea(a: Vec2, b: Vec2, c: Vec2) f64 {
    return @abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2.0;
}

pub fn polygonArea(vertices: []const Vec2) f64 {
    if (vertices.len < 3) return 0;
    var area: f64 = 0;
    for (0..vertices.len) |i| {
        const j = (i + 1) % vertices.len;
        area += vertices[i].x * vertices[j].y;
        area -= vertices[j].x * vertices[i].y;
    }
    return @abs(area) / 2.0;
}

pub fn polygonCentroid(vertices: []const Vec2) Vec2 {
    if (vertices.len == 0) return Vec2{ .x = 0, .y = 0 };
    var cx: f64 = 0; var cy: f64 = 0;
    for (vertices) |v| { cx += v.x; cy += v.y; }
    const n = @as(f64, @floatFromInt(vertices.len));
    return Vec2{ .x = cx / n, .y = cy / n };
}

pub fn pointInTriangle(p: Vec2, a: Vec2, b: Vec2, c: Vec2) bool {
    const d1 = sign(p, a, b);
    const d2 = sign(p, b, c);
    const d3 = sign(p, c, a);
    const has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0);
    const has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0);
    return !(has_neg and has_pos);
}

fn sign(p1: Vec2, p2: Vec2, p3: Vec2) f64 {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

pub fn lineIntersection(a1: Vec2, a2: Vec2, b1: Vec2, b2: Vec2) ?Vec2 {
    const d1 = vec2Sub(a2, a1);
    const d2 = vec2Sub(b2, b1);
    const cross = vec2Cross(d1, d2);
    if (@abs(cross) < 1e-10) return null;
    const d = vec2Sub(b1, a1);
    const t = vec2Cross(d, d2) / cross;
    return Vec2{ .x = a1.x + t * d1.x, .y = a1.y + t * d1.y };
}

pub fn closestPointOnSegment(p: Vec2, a: Vec2, b: Vec2) Vec2 {
    const ab = vec2Sub(b, a);
    const ap = vec2Sub(p, a);
    var t = vec2Dot(ap, ab) / vec2Dot(ab, ab);
    t = @max(0, @min(1, t));
    return Vec2{ .x = a.x + t * ab.x, .y = a.y + t * ab.y };
}

pub fn convexHull(points: []Vec2, hull: []Vec2) u32 {
    if (points.len < 3) {
        const n = @min(points.len, hull.len);
        @memcpy(hull[0..n], points[0..n]);
        return @intCast(n);
    }
    // Find lowest point
    var lowest: usize = 0;
    for (1..points.len) |i| {
        if (points[i].y < points[lowest].y or (points[i].y == points[lowest].y and points[i].x < points[lowest].x))
            lowest = i;
    }
    const tmp = points[0]; points[0] = points[lowest]; points[lowest] = tmp;
    // Jarvis march
    var count: u32 = 0;
    var current: usize = 0;
    while (true) {
        if (count >= hull.len) break;
        hull[count] = points[current];
        count += 1;
        var next: usize = 0;
        for (1..points.len) |i| {
            if (i == current) continue;
            const cross = vec2Cross(vec2Sub(points[i], points[current]), vec2Sub(points[next], points[current]));
            if (next == current or cross > 0) next = i;
        }
        current = next;
        if (current == 0) break;
        if (count > points.len) break;
    }
    return count;
}
