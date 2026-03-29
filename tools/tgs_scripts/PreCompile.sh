#!/bin/bash
# Force ARM Clang paths
export LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/
export BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/aarch64-linux-gnu/ -I/usr/include"

# USE '.' TO SOURCE - This keeps the variables alive in this script
if [ -f "./InstallDeps.sh" ]; then
    . ./InstallDeps.sh
fi

export PATH="$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"

set -e
set -x

# 1. Detect Host Architecture
ARCH=$(uname -m)
RUST_TARGET="$ARCH-unknown-linux-gnu"

# Load dep exports from game repo
original_dir=$PWD
cd "$1"
. dependencies.sh
cd "$original_dir"

# Bun Setup
if ! command -v bun >/dev/null 2>&1; then
    echo "Installing Bun for $ARCH..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# 2. Build rust-g for ARM64
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

# 3. Build dreamluau for ARM64
cd "$original_dir"
if [ ! -d "dreamluau" ]; then
    git clone https://github.com/tgstation/dreamluau
fi
cd dreamluau
git fetch
rustup target add "$RUST_TARGET"
git checkout "$DREAMLUAU_VERSION"

# Forced environment inline for the panic-prone bindgen
LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/ BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/aarch64-linux-gnu/ -I/usr/include" \
cargo build --ignore-rust-version --release --target="$RUST_TARGET"

cp -f "target/$RUST_TARGET/release/libdreamluau.so" "$1/libdreamluau.so"
cd ..

# 4. Compile TGUI
echo "Compiling tgui..."
cd "$1"
env TG_BOOTSTRAP_CACHE="$original_dir" CBT_BUILD_MODE="TGS" tools/bootstrap/javascript.sh tools/build/build.ts
