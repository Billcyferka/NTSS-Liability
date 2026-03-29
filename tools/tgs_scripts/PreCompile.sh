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

# 2. Build rust-g
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

# 3. Build dreamluau with 64-bit surgery
if [ ! -d "dreamluau" ]; then
    git clone https://github.com/tgstation/dreamluau
fi
cd dreamluau
git fetch
rustup target add "$RUST_TARGET"
git checkout "$DREAMLUAU_VERSION"

echo "Patching meowtonin for ARM64..."
cargo fetch --target="$RUST_TARGET"

# Surgery 1: version.rs (u32/u64 version/build numbers)
find ~/.cargo/git/checkouts/meowtonin-*/ -name "version.rs" -exec sed -i 's/(version, build)/(version.try_into().unwrap(), build.try_into().unwrap())/g' {} +

# Surgery 2: reference.rs (ByondValue_SetRef argument)
find ~/.cargo/git/checkouts/meowtonin-*/ -name "reference.rs" -exec sed -i 's/ref_id)/ref_id.into())/g' {} +

# Surgery 3: reference.rs (Some(result) return type)
find ~/.cargo/git/checkouts/meowtonin-*/ -name "reference.rs" -exec sed -i 's/Some(result)/Some(result.try_into().unwrap())/g' {} +

# Re-run build
LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/ cargo build --release --target="$RUST_TARGET"
cp -f "target/$RUST_TARGET/release/libdreamluau.so" "$1/libdreamluau.so"
cd ..

# 4. Compile TGUI
echo "Compiling tgui..."
cd "$1"
env TG_BOOTSTRAP_CACHE="$original_dir" CBT_BUILD_MODE="TGS" tools/bootstrap/javascript.sh tools/build/build.ts
