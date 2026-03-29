#!/bin/bash
# Force ARM Clang paths and suppress 64-bit pointer warnings
export LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/
export BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/aarch64-linux-gnu/ -I/usr/include"
export RUSTFLAGS="-A wide_pointer_conversions -A dead_code"

# Source the dependencies
if [ -f "./InstallDeps.sh" ]; then
    . ./InstallDeps.sh
fi

export PATH="$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"

set -e
set -x

# 1. Detect Host Architecture
ARCH=$(uname -m)
RUST_TARGET="$ARCH-unknown-linux-gnu"

# Load dependency versions from game repo
original_dir=$PWD
cd "$1"
. dependencies.sh
cd "$original_dir"

# Bun Setup for ARM
if ! command -v bun >/dev/null 2>&1; then
    echo "Installing Bun for $ARCH..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# 2. Build rust-g
if [ ! -d "rust-g" ]; then
    git clone https://github.com/tgstation/rust-g
fi
cd rust-g
git fetch
rustup target add "$RUST_TARGET"
git checkout "$RUST_G_VERSION"
cargo build --ignore-rust-version --release --target="$RUST_TARGET" --features allow_non_32bit
cp -f "target/$RUST_TARGET/release/librust_g.so" "$1/librust_g.so"
cd ..

# 3. Build dreamluau
# We use the master branch if the versioned one fails on 64-bit types
cd "$original_dir"
if [ ! -d "dreamluau" ]; then
    git clone https://github.com/tgstation/dreamluau
fi
cd dreamluau
git fetch
rustup target add "$RUST_TARGET"

# Check out the version, but fall back to master for 64-bit fixes if needed
git checkout "$DREAMLUAU_VERSION" || git checkout master

LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/ \
BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/aarch64-linux-gnu/ -I/usr/include" \
cargo build --ignore-rust-version --release --target="$RUST_TARGET"

cp -f "target/$RUST_TARGET/release/libdreamluau.so" "$1/libdreamluau.so"
cd ..

# 4. Compile TGUI
echo "Compiling tgui..."
cd "$1"
env TG_BOOTSTRAP_CACHE="$original_dir" CBT_BUILD_MODE="TGS" tools/bootstrap/javascript.sh tools/build/build.ts
