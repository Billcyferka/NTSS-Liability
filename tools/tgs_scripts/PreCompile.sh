#!/bin/bash
export LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/
export BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/aarch64-linux-gnu/ -I/usr/include"

if [ -f "./InstallDeps.sh" ]; then
    . ./InstallDeps.sh
fi

export PATH="$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
set -e
set -x

ARCH=$(uname -m)
RUST_TARGET="$ARCH-unknown-linux-gnu"

original_dir=$PWD
cd "$1"
. dependencies.sh
cd "$original_dir"

if ! command -v bun >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# 1. Build rust-g
if [ ! -d "rust-g" ]; then
    git clone https://github.com/tgstation/rust-g
fi
cd rust-g
git fetch
rustup target add "$RUST_TARGET"
git checkout "$RUST_G_VERSION"
cargo build --release --target="$RUST_TARGET" --features allow_non_32bit
cp -f "target/$RUST_TARGET/release/librust_g.so" "$1/librust_g.so"
cd ..

# 2. Build dreamluau
if [ ! -d "dreamluau" ]; then
    git clone https://github.com/tgstation/dreamluau
fi
cd dreamluau
git fetch
rustup target add "$RUST_TARGET"
git checkout "$DREAMLUAU_VERSION"

echo "Patching meowtonin dependency..."
cargo fetch --target="$RUST_TARGET"
MEOW_DIR=$(find ~/.cargo/git/checkouts/meowtonin-384090e48d1c1aa5/ -type d -name "sys" | head -n 1 | sed 's/\/crates\/sys//')
if [ -d "$MEOW_DIR" ]; then
    sed -i 's/(version, build)/(version.try_into().unwrap(), build.try_into().unwrap())/g' "$MEOW_DIR/crates/sys/src/version.rs"
    sed -i 's/ref_id)/ref_id.into())/g' "$MEOW_DIR/crates/core/src/value/reference.rs"
    sed -i 's/Some(result)/Some(result.try_into().unwrap())/g' "$MEOW_DIR/crates/core/src/value/reference.rs"
fi

echo "Patching DreamLuau source for ARM64 pointer types..."
# Fixes the 'expected *const u8, found *const i8' errors
# We use a broad regex to ensure we catch 'as *const i8' even with weird spacing
sed -i 's/as \*const i8/as \*const u8/g' src/state/util/entrypoint.rs
sed -i 's/as \*const i8/as \*const u8/g' src/state/util/traceback.rs

# Fix the 'expected u8, found i8' char literal errors
sed -i 's/as i8)/.try_into().unwrap())/g' src/state/util/traceback.rs

# Now build
LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/ cargo build --release --target="$RUST_TARGET"
cp -f "target/$RUST_TARGET/release/libdreamluau.so" "$1/libdreamluau.so"
cd ..

# 3. Compile TGUI
echo "Compiling tgui..."
cd "$1"
env TG_BOOTSTRAP_CACHE="$original_dir" CBT_BUILD_MODE="TGS" tools/bootstrap/javascript.sh tools/build/build.ts
