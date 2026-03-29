#!/bin/bash
# Hardcoded for 32-bit ARM to match the Box86/BYOND architecture
export RUST_TARGET="arm-unknown-linux-gnueabihf"
export PKG_CONFIG_ALLOW_CROSS=1
export CARGO_TARGET_ARM_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc

if [ -f "./InstallDeps.sh" ]; then
    . ./InstallDeps.sh
fi

export PATH="$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
set -e
set -x

original_dir=$PWD
cd "$1"
. dependencies.sh
cd "$original_dir"

if ! command -v bun >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# 1. Build rust-g (32-bit)
if [ ! -d "rust-g" ]; then
    git clone https://github.com/tgstation/rust-g
fi
cd rust-g
git fetch
rustup target add "$RUST_TARGET"
git checkout "$RUST_G_VERSION"
# Note: Removed --features allow_non_32bit because we ARE 32-bit now!
cargo build --release --target="$RUST_TARGET"
cp -f "target/$RUST_TARGET/release/librust_g.so" "$1/librust_g.so"
cd ..

# 2. Build dreamluau (32-bit)
if [ ! -d "dreamluau" ]; then
    git clone https://github.com/tgstation/dreamluau
fi
cd dreamluau
git fetch
rustup target add "$RUST_TARGET"
git checkout "$DREAMLUAU_VERSION"

# We can skip the ARM64 pointer patches because we are building for 32-bit ARM (armhf)
# which uses standard signed/unsigned char behavior like x86!

cargo build --release --target="$RUST_TARGET"
cp -f "target/$RUST_TARGET/release/libdreamluau.so" "$1/libdreamluau.so"
cd ..

# 3. Compile TGUI
echo "Compiling tgui..."
cd "$1"
env TG_BOOTSTRAP_CACHE="$original_dir" CBT_BUILD_MODE="TGS" tools/bootstrap/javascript.sh tools/build/build.ts
