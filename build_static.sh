#!/bin/bash
set -e

# Cross-compiles object files natively on the host, then statically links
# each architecture inside a minimal Alpine container. The Crystal compiler
# never runs under emulation; only the fast final link step does.
#
# NOTE: the linker image provides the C libraries the object files expect.
# Host Crystal >= 1.21 requires libxml2 >= 2.13 (Alpine >= 3.22).

mkdir -p build bin
rm -f bin/tartrazine-static-linux-amd64 bin/tartrazine-static-linux-arm64

shards install

echo "==> Cross-compiling x86_64 object file"
crystal build src/main.cr --release --static --cross-compile \
  --target x86_64-linux-musl -o build/tartrazine-x86_64.o

echo "==> Cross-compiling aarch64 object file"
crystal build src/main.cr --release --static --cross-compile \
  --target aarch64-linux-musl -o build/tartrazine-aarch64.o

echo "==> Building linker images"
docker build -q . -f Dockerfile.link --platform linux/amd64 -t tartrazine-linker-amd64
docker build -q . -f Dockerfile.link --platform linux/arm64 -t tartrazine-linker-arm64

LINK_FLAGS="-static -rdynamic -lgc -lpcre2-8 -lyaml -lxml2 -lz -llzma -lpthread -ldl -lm"

echo "==> Statically linking amd64 binary"
docker run --rm -v "$PWD":/app --user="$(id -u)" tartrazine-linker-amd64 \
  sh -c "cd /app && cc build/tartrazine-x86_64.o -o bin/tartrazine-static-linux-amd64 $LINK_FLAGS && strip bin/tartrazine-static-linux-amd64"

echo "==> Statically linking arm64 binary"
docker run --rm --platform linux/arm64 -v "$PWD":/app --user="$(id -u)" tartrazine-linker-arm64 \
  sh -c "cd /app && cc build/tartrazine-aarch64.o -o bin/tartrazine-static-linux-arm64 $LINK_FLAGS && strip bin/tartrazine-static-linux-arm64"

echo "==> Done"
ls -la bin/tartrazine-static-linux-*
