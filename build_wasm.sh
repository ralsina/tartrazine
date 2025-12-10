#!/bin/bash

# Build script for WebAssembly compilation
set -e

echo "Building Tartrazine for WebAssembly..."

# Set essential lexers for minimal WASM build
export TT_LEXERS="${TT_LEXERS:-plaintext,html,css,javascript,json,python,ruby,crystal}"

echo "Building with lexers: $TT_LEXERS"

# Build for WASM target using the existing selective lexer baking
crystal build src/wasm.cr \
  --target wasm32-unknown-unknown \
  -Dnolexers \
  -Dwasm32 \
  --release \
  -o tartrazine.wasm

echo "WASM build complete: tartrazine.wasm"
echo "Size: $(stat -c %s tartrazine.wasm | numfmt --to=iec)B"

# Note: JavaScript bindings would require wasm-bindgen or similar tool
# For now, this creates a basic WASM module that can be loaded directly

echo "Usage example:"
echo "  // In JavaScript"
echo "  const wasmModule = await WebAssembly.instantiateStreaming(fetch('tartrazine.wasm'));"
echo "  // Use Crystal functions exported from the WASM module"
