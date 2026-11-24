#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 26.04"
    echo "         $0 24.04"
    echo "         $0 22.04"
    exit 1
fi

if [ "$1" == "26.04" ]; then
    DOCKERFILE="./26.04-dockerfile/Dockerfile"
    OUTPUT="my-riscv-7.0.0-kernel"
elif [ "$1" == "24.04" ]; then
    DOCKERFILE="./24.04-dockerfile/Dockerfile"
    OUTPUT="my-riscv-6.8.12-kernel"
else
    echo "Invalid version: $1"
    echo "Supported versions: 26.04, 24.04, 22.04"
    exit 1
fi

if DOCKER_BUILDKIT=1 docker build --no-cache \
    --file "$DOCKERFILE" \
    --output "$OUTPUT" .; then
    echo "Build completed for $1: Output directory is $OUTPUT"
else
    echo "Build failed for $1"
    exit 1
fi