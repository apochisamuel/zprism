const std = @import("std");
const types = @import("types.zig");

pub const SchemaField = struct { name: []const u8, field_type: FieldType, required: bool, min_val: u32, max_val: u32 };
pub const FieldType = enum { uint8, uint16, uint32, uint64, string_ref, attr_ref, section_ref };
pub const SchemaRule = struct { section_type: types.SectionType, fields: []const SchemaField };

pub const ValidationResult = struct {
    valid: bool, errors: u32, warnings: u32,
    first_error_section: u32, first_error_field: u32,
};

pub fn validateSchema(doc: *const types.Document, rules: []const SchemaRule) ValidationResult {
    var result = ValidationResult{ .valid = true, .errors = 0, .warnings = 0, .first_error_section = 0, .first_error_field = 0 };
    for (rules) |*rule| {
        if (doc.raw_sections) |secs| {
            for (secs, 0..) |*sec, si| {
                if (sec.section_type == rule.section_type) {
                    for (rule.fields, 0..) |*field, fi| {
                        if (!validateField(doc, sec, field)) {
                            result.errors += 1;
                            if (result.valid) {
                                result.first_error_section = @intCast(si);
                                result.first_error_field = @intCast(fi);
                            }
                            result.valid = false;
                        }
                    }
                }
            }
        }
    }
    return result;
}

fn validateField(doc: *const types.Document, sec: *const types.RawSection, field: *const SchemaField) bool {
    _ = doc; _ = sec; _ = field;
    return true;
}

pub fn inferSchema(doc: *const types.Document) u32 {
    var field_count: u32 = 0;
    if (doc.symbols.count > 0) field_count += 4;
    if (doc.strings.count > 0) field_count += 3;
    if (doc.attrs.count > 0) field_count += 4;
    if (doc.relocs.count > 0) field_count += 5;
    if (doc.events.count > 0) field_count += 6;
    return field_count;
}

pub fn schemaCompatible(a: *const types.Document, b: *const types.Document) bool {
    if (a.header.version != b.header.version) return false;
    if (a.header.section_count != b.header.section_count) return false;
    if (a.raw_sections != null and b.raw_sections != null) {
        const sa = a.raw_sections.?;
        const sb = b.raw_sections.?;
        if (sa.len != sb.len) return false;
        for (sa, sb) |*x, *y| {
            if (x.section_type != y.section_type) return false;
        }
    }
    return true;
}
