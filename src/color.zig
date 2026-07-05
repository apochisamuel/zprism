const std = @import("std");

pub const RGB = struct { r: f64, g: f64, b: f64 };
pub const HSL = struct { h: f64, s: f64, l: f64 };
pub const HSV = struct { h: f64, s: f64, v: f64 };
pub const CMYK = struct { c: f64, m: f64, y: f64, k: f64 };
pub const Lab = struct { l: f64, a: f64, b: f64 };

pub fn rgbToHsl(rgb: RGB) HSL {
    const mx = @max(rgb.r, @max(rgb.g, rgb.b));
    const mn = @min(rgb.r, @min(rgb.g, rgb.b));
    const l = (mx + mn) / 2.0;
    if (mx == mn) return HSL{ .h = 0, .s = 0, .l = l };
    const d = mx - mn;
    const s = if (l > 0.5) d / (2.0 - mx - mn) else d / (mx + mn);
    var h: f64 = 0;
    if (mx == rgb.r) h = (rgb.g - rgb.b) / d + (if (rgb.g < rgb.b) 6.0 else 0.0)
    else if (mx == rgb.g) h = (rgb.b - rgb.r) / d + 2.0
    else h = (rgb.r - rgb.g) / d + 4.0;
    return HSL{ .h = h / 6.0, .s = s, .l = l };
}

pub fn hslToRgb(hsl: HSL) RGB {
    if (hsl.s == 0) return RGB{ .r = hsl.l, .g = hsl.l, .b = hsl.l };
    const q = if (hsl.l < 0.5) hsl.l * (1.0 + hsl.s) else hsl.l + hsl.s - hsl.l * hsl.s;
    const p = 2.0 * hsl.l - q;
    return RGB{
        .r = hueToRgb(p, q, hsl.h + 1.0 / 3.0),
        .g = hueToRgb(p, q, hsl.h),
        .b = hueToRgb(p, q, hsl.h - 1.0 / 3.0),
    };
}

fn hueToRgb(p: f64, q: f64, t_in: f64) f64 {
    var t = t_in;
    if (t < 0) t += 1; if (t > 1) t -= 1;
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
}

pub fn rgbToHsv(rgb: RGB) HSV {
    const mx = @max(rgb.r, @max(rgb.g, rgb.b));
    const mn = @min(rgb.r, @min(rgb.g, rgb.b));
    const d = mx - mn;
    var h: f64 = 0;
    if (d != 0) {
        if (mx == rgb.r) h = @mod((rgb.g - rgb.b) / d, 6.0)
        else if (mx == rgb.g) h = (rgb.b - rgb.r) / d + 2.0
        else h = (rgb.r - rgb.g) / d + 4.0;
        h /= 6.0;
    }
    return HSV{ .h = h, .s = if (mx == 0) 0 else d / mx, .v = mx };
}

pub fn rgbToCmyk(rgb: RGB) CMYK {
    const k = 1.0 - @max(rgb.r, @max(rgb.g, rgb.b));
    if (k >= 1.0) return CMYK{ .c = 0, .m = 0, .y = 0, .k = 1 };
    return CMYK{
        .c = (1.0 - rgb.r - k) / (1.0 - k),
        .m = (1.0 - rgb.g - k) / (1.0 - k),
        .y = (1.0 - rgb.b - k) / (1.0 - k),
        .k = k,
    };
}

pub fn cmykToRgb(cmyk: CMYK) RGB {
    return RGB{
        .r = (1.0 - cmyk.c) * (1.0 - cmyk.k),
        .g = (1.0 - cmyk.m) * (1.0 - cmyk.k),
        .b = (1.0 - cmyk.y) * (1.0 - cmyk.k),
    };
}

pub fn rgbToLab(rgb: RGB) Lab {
    var x = rgb.r * 0.4124564 + rgb.g * 0.3575761 + rgb.b * 0.1804375;
    var y = rgb.r * 0.2126729 + rgb.g * 0.7151522 + rgb.b * 0.0721750;
    var z = rgb.r * 0.0193339 + rgb.g * 0.1191920 + rgb.b * 0.9503041;
    x /= 0.95047; y /= 1.0; z /= 1.08883;
    x = labF(x); y = labF(y); z = labF(z);
    return Lab{ .l = 116.0 * y - 16.0, .a = 500.0 * (x - y), .b = 200.0 * (y - z) };
}

fn labF(t: f64) f64 {
    if (t > 0.008856) return std.math.cbrt(t);
    return 7.787 * t + 16.0 / 116.0;
}

pub fn colorDistance(a: RGB, b: RGB) f64 {
    const la = rgbToLab(a);
    const lb = rgbToLab(b);
    const dl = la.l - lb.l;
    const da = la.a - lb.a;
    const db = la.b - lb.b;
    return @sqrt(dl * dl + da * da + db * db);
}

pub fn lerp(a: RGB, b: RGB, t: f64) RGB {
    return RGB{
        .r = a.r + (b.r - a.r) * t,
        .g = a.g + (b.g - a.g) * t,
        .b = a.b + (b.b - a.b) * t,
    };
}

pub fn complement(c: RGB) RGB {
    return RGB{ .r = 1.0 - c.r, .g = 1.0 - c.g, .b = 1.0 - c.b };
}

pub fn grayscale(c: RGB) f64 { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }

pub fn contrast(a: RGB, b: RGB) f64 {
    const la = grayscale(a) + 0.05;
    const lb = grayscale(b) + 0.05;
    return if (la > lb) la / lb else lb / la;
}

pub fn rgbToU32(c: RGB) u32 {
    const r: u32 = @intFromFloat(@min(255.0, @max(0.0, c.r * 255.0)));
    const g: u32 = @intFromFloat(@min(255.0, @max(0.0, c.g * 255.0)));
    const b: u32 = @intFromFloat(@min(255.0, @max(0.0, c.b * 255.0)));
    return (r << 16) | (g << 8) | b;
}

pub fn u32ToRgb(val: u32) RGB {
    return RGB{
        .r = @as(f64, @floatFromInt((val >> 16) & 0xFF)) / 255.0,
        .g = @as(f64, @floatFromInt((val >> 8) & 0xFF)) / 255.0,
        .b = @as(f64, @floatFromInt(val & 0xFF)) / 255.0,
    };
}

pub fn palette(count: u32, output: []RGB) u32 {
    const n = @min(count, @as(u32, @intCast(output.len)));
    for (0..n) |i| {
        const hue = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        output[i] = hslToRgb(HSL{ .h = hue, .s = 0.7, .l = 0.5 });
    }
    return n;
}

pub fn quantize(colors: []RGB, palette_size: u32, output: []RGB) u32 {
    if (colors.len == 0 or palette_size == 0) return 0;
    const n = @min(palette_size, @as(u32, @intCast(@min(colors.len, output.len))));
    const step = @max(colors.len / n, 1);
    var count: u32 = 0;
    var i: usize = 0;
    while (i < colors.len and count < n) {
        output[count] = colors[i]; count += 1; i += step;
    }
    return count;
}

pub fn dominantColor(colors: []const RGB) RGB {
    if (colors.len == 0) return RGB{ .r = 0, .g = 0, .b = 0 };
    var sr: f64 = 0; var sg: f64 = 0; var sb: f64 = 0;
    for (colors) |c| { sr += c.r; sg += c.g; sb += c.b; }
    const n = @as(f64, @floatFromInt(colors.len));
    return RGB{ .r = sr / n, .g = sg / n, .b = sb / n };
}
