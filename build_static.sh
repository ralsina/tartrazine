#!/bin/bash
set -e

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
docker build . -f Dockerfile.static -t tartrazine-builder
docker run -ti --rm -v "$PWD":/app --user="$UID" tartrazine-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && make static"
mv bin/tartrazine bin/tartrazine-static-linux-amd64

# Build for ARM64
docker build . -f Dockerfile.static --platform linux/arm64 -t tartrazine-builder
docker run -ti --rm -v "$PWD":/app --platform linux/arm64 --user="$UID" tartrazine-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && make static"
mv bin/tartrazine bin/tartrazine-static-linux-arm64
