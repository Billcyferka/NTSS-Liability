#!/bin/bash
# Tell the compiler where to find Clang on ARM64
export LIBCLANG_PATH=/usr/lib/aarch64-linux-gnu/

# find out what we have (+e is important for this)
set +e
has_git="$(command -v git)"
has_curl="$(command -v curl)"
has_cargo="$(command -v ~/.cargo/bin/cargo)"
has_sudo="$(command -v sudo)"
has_ytdlp="$(command -v yt-dlp)"
has_pip3="$(command -v pip3)"
has_unzip="$(command -v unzip)"
set -e
set -x

# 1. Native ARM dependencies (No i386/Intel stuff)
# We check for libssl.so in the AARCH64 folder instead of i386
if ! ( [ -x "$has_git" ] && [ -x "$has_curl" ] && [ -x "$has_pip3" ] && [ -x "$has_unzip" ] && [ -f "/usr/lib/aarch64-linux-gnu/libssl.so" ] ); then
    echo "Installing Native ARM Dependencies..."

    # Define the package list for ARM64
    ARM_PACKAGES="git pkg-config libssl-dev zlib1g-dev curl libclang-dev g++ python3 python3-pip unzip"

    if [ -x "$has_sudo" ]; then
        sudo apt-get update
        sudo apt-get install -y $ARM_PACKAGES
    else
        apt-get update
        apt-get install -y $ARM_PACKAGES
    fi
fi

# 2. Install cargo if needed
if ! [ -x "$has_cargo" ]; then
    echo "Installing rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    . ~/.profile
fi

# 3. Handle yt-dlp
if ! [ -x "$has_ytdlp" ]; then
    echo "Installing yt-dlp with pip3..."
    pip3 install yt-dlp --break-system-packages
else
    echo "Ensuring yt-dlp is up-to-date..."
    pip3 install yt-dlp -U --break-system-packages
fi
