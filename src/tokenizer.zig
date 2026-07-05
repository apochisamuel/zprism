const std = @import("std");

pub const TokenType = enum { word, number, symbol, whitespace, punctuation, unknown };
pub const Token = struct { start: u32, length: u32, token_type: TokenType, hash: u32 };

pub fn tokenize(data: []const u8, tokens: []Token) u32 {
    var count: u32 = 0;
    var i: usize = 0;
    while (i < data.len and count < tokens.len) {
        if (isWhitespace(data[i])) {
            const start = i;
            while (i < data.len and isWhitespace(data[i])) i += 1;
            tokens[count] = Token{ .start = @intCast(start), .length = @intCast(i - start), .token_type = .whitespace, .hash = 0 };
            count += 1;
        } else if (isAlpha(data[i])) {
            const start = i;
            while (i < data.len and (isAlpha(data[i]) or isDigit(data[i]) or data[i] == '_')) i += 1;
            tokens[count] = Token{ .start = @intCast(start), .length = @intCast(i - start), .token_type = .word, .hash = hashSlice(data[start..i]) };
            count += 1;
        } else if (isDigit(data[i])) {
            const start = i;
            while (i < data.len and (isDigit(data[i]) or data[i] == '.' or data[i] == 'x' or data[i] == 'X')) i += 1;
            tokens[count] = Token{ .start = @intCast(start), .length = @intCast(i - start), .token_type = .number, .hash = hashSlice(data[start..i]) };
            count += 1;
        } else if (isPunctuation(data[i])) {
            tokens[count] = Token{ .start = @intCast(i), .length = 1, .token_type = .punctuation, .hash = @as(u32, data[i]) };
            count += 1; i += 1;
        } else {
            tokens[count] = Token{ .start = @intCast(i), .length = 1, .token_type = .unknown, .hash = @as(u32, data[i]) };
            count += 1; i += 1;
        }
    }
    return count;
}

pub fn countTokenTypes(tokens: []const Token, count: u32) [6]u32 {
    var result = [_]u32{0} ** 6;
    for (tokens[0..count]) |*t| {
        result[@intFromEnum(t.token_type)] += 1;
    }
    return result;
}

pub fn uniqueTokens(tokens: []const Token, count: u32) u32 {
    var hashes: [4096]u32 = undefined;
    var n: u32 = 0;
    for (tokens[0..count]) |*t| {
        if (t.token_type == .whitespace) continue;
        var found = false;
        for (hashes[0..n]) |h| { if (h == t.hash) { found = true; break; } }
        if (!found and n < 4096) { hashes[n] = t.hash; n += 1; }
    }
    return n;
}

pub fn nGrams(tokens: []const Token, count: u32, n: u32, output: []u32) u32 {
    if (count < n) return 0;
    var out_count: u32 = 0;
    for (0..count - n + 1) |i| {
        if (out_count >= output.len) break;
        var h: u32 = 0;
        for (0..n) |j| h = h *% 31 +% tokens[i + j].hash;
        output[out_count] = h;
        out_count += 1;
    }
    return out_count;
}

pub fn tokenFrequency(tokens: []const Token, count: u32, freq: *[256]u32) void {
    for (freq) |*f| f.* = 0;
    for (tokens[0..count]) |*t| {
        freq[@as(u8, @truncate(t.hash))] += 1;
    }
}

pub fn tfidf(token_freq: u32, doc_freq: u32, total_docs: u32) f64 {
    if (token_freq == 0 or doc_freq == 0 or total_docs == 0) return 0;
    const tf = @as(f64, @floatFromInt(token_freq));
    const idf = @log2(@as(f64, @floatFromInt(total_docs)) / @as(f64, @floatFromInt(doc_freq)));
    return tf * idf;
}

fn isWhitespace(c: u8) bool { return c == ' ' or c == '\t' or c == '\n' or c == '\r'; }
fn isAlpha(c: u8) bool { return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_'; }
fn isDigit(c: u8) bool { return c >= '0' and c <= '9'; }
fn isPunctuation(c: u8) bool { return c == '.' or c == ',' or c == ';' or c == ':' or c == '!' or c == '?'; }
fn hashSlice(data: []const u8) u32 {
    var h: u32 = 0x811c9dc5;
    for (data) |b| { h ^= @as(u32, b); h *%= 0x01000193; }
    return h;
}
