# zprism

A Zig library for parsing, validating, and analyzing PRISM (.prm) binary container files.

## What is PRISM?

PRISM is a structured binary container format designed for storing interrelated event data, symbol tables, relocations, and metadata in a single file. It is used in instrumentation pipelines where multiple data streams (events, keyframes, aliases) need to be cross-referenced through a shared symbol and relocation table.

A `.prm` file contains:

- **Header** — magic number, version, flags, section/directory counts
- **Directory** — typed entries describing each section's offset, size, element count, and link chain
- **Sections** — raw data blocks for each subsystem (strings, symbols, attributes, relocations, events, keyframes, streams, aliases)

## Architecture

The parser follows a multi-phase pipeline:

1. **Parse** — `header` → `directory` → `sections` → `strings` → `attrs` → `symbols` → `relocs` → `events` → `keyframes` → `streams` → `aliases`
2. **Validate** — cross-section consistency checks with configurable rollback on integrity violations
3. **Resolve** — link symbols to their string names and attribute entries, apply relocations
4. **Cache** — build name indices, compute integrity hashes, materialize alias views

### Source layout

```
src/
├── parser.zig        # Main pipeline: openMemory / closeDocument
├── types.zig         # All type definitions (Document, Header, Symbol, etc.)
├── header.zig        # Header parsing and validation
├── directory.zig     # Directory entry parsing, link chain traversal
├── sections.zig      # Raw section capture from input buffer
├── strings.zig       # String table loading, rollback, lookup
├── symbols.zig       # Symbol parsing, score computation
├── attrs.zig         # Attribute table parsing and rollback
├── reloc.zig         # Relocation parsing and application
├── events.zig        # Event/frame parsing with XOR payload decode
├── keyframes.zig     # Keyframe parsing and span computation
├── streams.zig       # Stream parsing and materialization
├── aliases.zig       # Alias blob parsing with ownership tracking
├── validate.zig      # Multi-condition validation with affinity scoring
├── resolve.zig       # Symbol name/attr resolution, reloc target resolution
├── cache.zig         # Name index building, integrity hashing
├── analysis.zig      # Document-level analysis and quality scoring
├── integrity.zig     # Structural integrity verification
├── graph.zig         # Dependency graph construction and PageRank
├── query.zig         # Predicate-based symbol/reloc/event queries
├── search.zig        # String search with fuzzy matching
├── filter.zig        # Symbol and event filtering
├── index.zig         # Hash-based lookup indices
├── iterator.zig      # Typed iterators for symbols, events, relocs
├── transform.zig     # Payload transforms, histogram equalization
├── compress.zig      # RLE, LZ, delta compression
├── encoding.zig      # Base64, hex, varint encoding
├── hashing.zig       # FNV, Murmur3, xxHash, CRC32, Bloom filters
├── fingerprint.zig   # Document fingerprinting and similarity
├── stats.zig         # Statistical analysis (percentiles, correlation)
├── regression.zig    # Linear/polynomial regression, anomaly detection
├── clustering.zig    # K-means, DBSCAN clustering
├── projection.zig    # 2D projection and spatial queries
├── correlation.zig   # Pearson/Spearman correlation, mutual information
├── matrix.zig        # Dense matrix operations
├── sparse.zig        # Sparse matrix operations
├── signal.zig        # Signal processing (filters, FFT, peak detection)
├── wavelet.zig       # Haar wavelet transform and denoising
├── interpolation.zig # Lagrange, Hermite, Bezier interpolation
├── optimization.zig  # Golden section, Newton-Raphson, numerical integration
├── probability.zig   # PDF/CDF, Bayes theorem, hypothesis testing
├── random.zig        # PRNG (LCG, XorShift), sampling, distributions
├── automata.zig      # DFA construction, minimization, language ops
├── state_machine.zig # Configurable state machine for parser lifecycle
├── scheduler.zig     # Priority task scheduler with dependency tracking
├── geometry.zig      # 2D/3D vector math, collision detection, convex hull
├── quadtree.zig      # Spatial indexing with range/nearest queries
├── interval.zig      # Interval tree with overlap/gap analysis
├── color.zig         # RGB/HSL/HSV/CMYK/Lab color space conversion
├── codec.zig         # XOR, Caesar, Vigenere, substitution ciphers
├── checksum.zig      # Fletcher, Luhn, Verhoeff, Damm, ISBN checksums
├── numeric.zig       # Number theory (GCD, primes, Fibonacci, statistics)
├── sorting.zig       # Insertion, shell, heap, radix, counting sort
├── trie.zig          # Prefix trie with search and longest common prefix
├── skiplist.zig      # Skip list with range queries
├── ringbuf.zig       # Generic ring buffer
├── deque.zig         # Double-ended queue
├── heap.zig          # Min-heap with top-K extraction
├── unionfind.zig     # Disjoint set with path compression and Kruskal MST
├── lru_cache.zig     # LRU eviction cache
├── bloom.zig         # Bloom filter with Jaccard similarity
├── consistent_hash.zig # Consistent hashing with virtual nodes
├── bitstream.zig     # Bit-level reader/writer
├── pool.zig          # Block-based memory pool
├── intern.zig        # String interning table
├── window.zig        # Sliding window statistics
├── sampler.zig       # Uniform, weighted, stratified, reservoir sampling
├── snapshot.zig      # Document state snapshots and drift detection
├── tokenizer.zig     # Byte-level tokenizer with n-gram hashing
├── writer.zig        # Binary serialization
├── export.zig        # CSV/text export
├── format.zig        # Human-readable formatting
├── diagnostic.zig    # Diagnostic reporting
├── inspector.zig     # Deep structural inspection
├── catalog.zig       # Symbol catalog with ranking
├── relocator.zig     # Relocation analysis and clustering
├── layout.zig        # Memory layout and fragmentation analysis
├── schema.zig        # Schema inference and validation
├── timeline.zig      # Event timeline construction
├── merge.zig         # Document merging
├── diff.zig          # Document comparison with edit distance
├── optimize.zig      # Deduplication and compaction analysis
├── patch_mod.zig     # Patch set application and revert
fuzz/
├── parse_fuzzer.zig    # Fuzz harness: parse → close cycle
├── entry_fuzzer.zig    # Fuzz harness: entry point variant
├── resolve_fuzzer.zig  # Fuzz harness: full resolve path
```

## Building

Requires Zig 0.16+.

```bash
# Build library object
zig build-obj --dep parser -Mroot=fuzz/parse_fuzzer.zig -Mparser=src/parser.zig -lc

# Run with zig build
zig build
```

## Fuzzing

The repository includes ClusterFuzzLite-compatible harnesses in `fuzz/` and configuration in `.clusterfuzzlite/`.

## License

MIT
