const std = @import("std");

pub const MAGIC: u32 = 0x5052534D; // "PRSM"
pub const VERSION: u16 = 1;
pub const MAX_SECTIONS: u32 = 64;
pub const MAX_DIRECTORY: u32 = 128;
pub const MAX_SYMBOLS: u32 = 4096;
pub const MAX_STRINGS: u32 = 4096;
pub const MAX_ATTRS: u32 = 4096;
pub const MAX_RELOCS: u32 = 8192;
pub const MAX_EVENTS: u32 = 8192;
pub const MAX_KEYFRAMES: u32 = 2048;
pub const MAX_STREAMS: u32 = 256;
pub const MAX_ALIASES: u32 = 512;

pub const FLAG_ROLLBACK_ATTRS: u32 = 0x0100;
pub const FLAG_ROLLBACK_STRINGS: u32 = 0x0200;
pub const FLAG_ALIAS_UNWIND: u32 = 0x0400;
pub const FLAG_KEY_UNWIND: u32 = 0x1000;
pub const FLAG_TYPE_SWEEP: u32 = 0x2000;
pub const FLAG_FRAME_TRUST: u32 = 0x4000;
pub const FLAG_COMPACT_ARENA: u32 = 0x8000;

pub const SectionType = enum(u8) {
    invalid = 0,
    strings = 1,
    symbols = 2,
    attrs = 3,
    relocs = 4,
    events = 5,
    keyframes = 6,
    streams = 7,
    aliases = 8,
    directory = 9,
    _,
};

pub const Header = struct {
    magic: u32,
    version: u16,
    flags: u32,
    section_count: u16,
    directory_count: u16,
    file_id: u32,
    total_size: u32,
    reserved: [8]u8,
};

pub const DirectoryEntry = struct {
    section_type: SectionType,
    offset: u32,
    size: u32,
    count: u32,
    link: u32,
    aux: u32,
};

pub const RawSection = struct {
    section_type: SectionType,
    data: []const u8,
    offset: u32,
    size: u32,
    index: u32,
};

pub const PrismString = struct {
    data: ?[]const u8,
    length: u32,
    hash: u32,
    arena_offset: u32,
    owned: bool,
};

pub const StringTable = struct {
    items: ?[]PrismString,
    count: u32,
    capacity: u32,
    rolled_back: bool,
    generation: u32,
    arena_base: ?[*]u8,
    arena_size: u32,
    arena_generation: u32,
};

pub const Attr = struct {
    value: u32,
    flags: u32,
    tag: u16,
    reserved: u16,
};

pub const AttrTable = struct {
    items: ?[]Attr,
    count: u32,
    capacity: u32,
    rolled_back: bool,
};

pub const Symbol = struct {
    name_index: u32,
    attr_index: u32,
    klass: u16,
    sym_flags: u16,
    derived_score: u32,
    name_ref: ?[]const u8,
    cached_attr: ?*Attr,
};

pub const SymbolTable = struct {
    items: ?[]Symbol,
    count: u32,
    capacity: u32,
};

pub const DiskSymbol = extern struct {
    name_index: u32,
    attr_index: u32,
    klass: u16,
    flags: u16,
    aux: u32,
};

pub const Reloc = struct {
    section_index: u32,
    symbol_index: u32,
    target: u32,
    reloc_type: u16,
    reloc_flags: u16,
    resolved_hash: u32,
};

pub const RelocTable = struct {
    items: ?[]Reloc,
    count: u32,
    capacity: u32,
    directory_index: u32,
};

pub const Event = struct {
    payload: ?[]u8,
    payload_len: u32,
    storage_len: u32,
    mode: u8,
    event_type: u8,
    sequence: u16,
    checksum: u32,
    timestamp: u64,
};

pub const EventTable = struct {
    items: ?[]Event,
    count: u32,
    capacity: u32,
};

pub const Keyframe = struct {
    frame_no: u32,
    name_index: u32,
    marker: u32,
    offset: u32,
    label: ?[]const u8,
};

pub const KeyframeTable = struct {
    items: ?[]Keyframe,
    count: u32,
    capacity: u32,
};

pub const Stream = struct {
    stream_id: u32,
    key_index: u32,
    event_count: u32,
    flags: u32,
    key_cache: ?*Keyframe,
    materialized: bool,
};

pub const StreamTable = struct {
    items: ?[]Stream,
    count: u32,
    capacity: u32,
};

pub const AliasBlob = struct {
    id: u32,
    size: u32,
    bytes: ?[]u8,
    owner_id: u32,
    cache_owned: bool,
};

pub const AliasList = struct {
    items: ?[]?*AliasBlob,
    count: u32,
    capacity: u32,
    generation: u32,
};

pub const Cache = struct {
    primary_strings: ?*StringTable,
    name_index: ?[]*PrismString,
    name_count: u32,
    combined_hash: u32,
    integrity_score: u32,
    string_gen_snap: u32,
    alias_gen_snap: u32,
    alias_views: ?[]?[*]const u8,
    alias_view_lens: ?[]u32,
    alias_view_count: u32,
    owned_aliases: ?[]?*AliasBlob,
    owned_alias_count: u32,
};

pub const Document = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    header: Header,
    directory: ?[]DirectoryEntry,
    directory_count: u32,
    raw_sections: ?[]RawSection,
    raw_count: u32,
    strings: StringTable,
    attrs: AttrTable,
    symbols: SymbolTable,
    relocs: RelocTable,
    events: EventTable,
    keyframes: KeyframeTable,
    streams: StreamTable,
    aliases: AliasList,
    cache: Cache,
    warning_count: u32,
    fatal_error: bool,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Document {
        return Document{
            .allocator = allocator,
            .input = input,
            .header = std.mem.zeroes(Header),
            .directory = null,
            .directory_count = 0,
            .raw_sections = null,
            .raw_count = 0,
            .strings = std.mem.zeroes(StringTable),
            .attrs = std.mem.zeroes(AttrTable),
            .symbols = std.mem.zeroes(SymbolTable),
            .relocs = std.mem.zeroes(RelocTable),
            .events = std.mem.zeroes(EventTable),
            .keyframes = std.mem.zeroes(KeyframeTable),
            .streams = std.mem.zeroes(StreamTable),
            .aliases = std.mem.zeroes(AliasList),
            .cache = std.mem.zeroes(Cache),
            .warning_count = 0,
            .fatal_error = false,
        };
    }
};

pub const ParseError = error{
    InvalidMagic,
    InvalidVersion,
    Truncated,
    InvalidSection,
    InvalidDirectory,
    AllocationFailed,
    TooManySections,
    TooManySymbols,
    TooManyStrings,
    InvalidReloc,
    InvalidEvent,
    InvalidKeyframe,
    InvalidStream,
    InvalidAlias,
    Overflow,
};
// EOF
