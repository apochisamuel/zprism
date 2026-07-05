#!/bin/bash
set -ex
cd "$SRC"

for fuzzer in fuzz/*_fuzzer.zig; do
    name=$(basename "$fuzzer" .zig)
    compile_zig_fuzzer "fuzz/${name}.zig" "${name}"
done
