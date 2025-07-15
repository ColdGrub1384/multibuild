#!/bin/bash

shopt -s expand_aliases

export OLD_PATH="$PATH"

if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Pass the version of Python to which compile the extensions, and optionally a tag name to checkout."
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

export VERSION="$1"
export PLAIN_VERSION="${VERSION//.}"
export XCRUN="iosxcrun"

export _PYTHON_EXECUTABLE="$(which "python$VERSION")"
export _PKG_CONFIG_EXECUTABLE="$(which pkg-config)"
export _RUSTC_EXECUTABLE="$(which rustc)"
export _CARGO_EXECUTABLE="$(which cargo)"

export TOOLS_DIR="$PWD"

if [ -z "$IOSSDK" ] && [ -z "$MAC_CATALYST" ] && [ -z "$WATCHOSSDK" ] && [ -z "$TVOSSDK" ]; then # Other platforms

    exit 1

elif [ "$TVOSSDK" = "appletvos" ] || [ "$TVOSSDK" = "appletvsimulator" ]; then # tvOS

    export ARCHITECTURE="${TVOSARCH// /-}"
    export S="$TVOSSDK-$ARCHITECTURE-cpython-$PLAIN_VERSION"
    export SDK="$(xcrun --sdk $TVOSSDK --show-sdk-path)"

    export PLATFORM="$TVOSSDK"
    export SDK_NAME="$TVOSSDK"
    export ARCHS="$TVOSARCH"
    export TVOS_DEPLOYMENT_TARGET=13.0
    export MINIMUM_OS_VERSION=13.0
    export ENDIAN="big"

    if [ "$TVOSARCH" = "arm64" ]; then
        export ARCHITECTURE_RUST="aarch64"
    else
        export ARCHITECTURE_RUST="x86_64"
    fi
    
    if [ "$TVOSSDK" = "appletvos" ]; then
        export _PLATFORM=TVOS
        export TARGET_TRIPLE="$ARCHITECTURE-apple-tvos13.0"
        export XCODE_DESTINATION_PLATFORM="tvOS"
        export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-tvos --build=$(clang -dumpmachine)"
        export MINVERSION_FLAG="-mtvos-version-min=$TVOS_DEPLOYMENT_TARGET"
        export INFO_PLATFORM_NAME="AppleTVOS"
    elif [ "$TVOSSDK" = "appletvsimulator" ]; then
        export _PLATFORM=SIMULATOR_TVOS
        export TARGET_TRIPLE="$ARCHITECTURE-apple-tvos13.0-simulator"
        export XCODE_DESTINATION_PLATFORM="tvOS Simulator"
        export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-tvos13.0-simulator --build=$(clang -dumpmachine)"
        export MINVERSION_FLAG="-mappletvsimulator-version-min=$TVOS_DEPLOYMENT_TARGET"
        export INFO_PLATFORM_NAME="AppleTVSimulator"
    fi
    
    export XCODEBUILD_ADDITIONAL_FLAGS="-sdk '$TVOSSDK' -destination 'generic/platform=$XCODE_DESTINATION_PLATFORM' PATH='$OLD_PATH' ARCHS='$TVOSARCH' ONLY_ACTIVE_ARCH=NO"

    export SYSTEM="darwin"
    export SUBSYSTEM="tvOS"

elif [ "$WATCHOSSDK" = "watchos" ] || [ "$WATCHOSSDK" = "watchsimulator" ]; then # watchOS

    export S="$WATCHOSSDK-$WATCHOSARCH-cpython-$PLAIN_VERSION"
    export SDK="$(xcrun --sdk $WATCHOSSDK --show-sdk-path)"

    export ARCHS="$WATCHOSARCH"
    export PLATFORM="$WATCHOSSDK"
    export SDK_NAME="$WATCHOSSDK"
    export ARCHITECTURE="${WATCHOSARCH// /-}"
    export WATCHOS_DEPLOYMENT_TARGET=6.0
    export MINIMUM_OS_VERSION=6.0

    if [ "$WATCHOSARCH" = "arm64" ]; then
        export ARCHITECTURE_RUST="aarch64"
        export ENDIAN="big"
    elif [ "$WATCHOSARCH" = "arm64_32" ]; then
        export ARCHITECTURE_RUST="arm64_32"
        export ADDITIONAL_MESON_PROPERTIES="longdouble_format = 'IEEE_DOUBLE_LE'"
        export ENDIAN="little"
    elif [ "$WATCHOSARCH" = "armv7k" ]; then
        export ARCHITECTURE_RUST="armv7k"
        export ADDITIONAL_MESON_PROPERTIES="longdouble_format = 'IEEE_DOUBLE_LE'"
        export ENDIAN="little"
    else
        export ARCHITECTURE_RUST="x86_64"
        export ENDIAN="big"
    fi

    if [ "$WATCHOSSDK" = "watchos" ]; then
        export _PLATFORM=WATCHOS64
        export TARGET_TRIPLE="$ARCHITECTURE-apple-watchos6.0"
        export XCODE_DESTINATION_PLATFORM="watchOS"
        export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-watchos --build=$(clang -dumpmachine)"
        export MINVERSION_FLAG="-mwatchos-version-min=$WATCHOS_DEPLOYMENT_TARGET"
        export INFO_PLATFORM_NAME="WatchOS"
    elif [ "$WATCHOSSDK" = "watchsimulator" ]; then
        export _PLATFORM=SIMULATOR_WATCHOSCOMBINED
        export TARGET_TRIPLE="$ARCHITECTURE-apple-watchos6.0-simulator"
        export XCODE_DESTINATION_PLATFORM="watchOS Simulator"
        export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-watchos6.0-simulator --build=$(clang -dumpmachine)"
        export MINVERSION_FLAG="-mwatchsimulator-version-min=$WATCHOS_DEPLOYMENT_TARGET"
        export INFO_PLATFORM_NAME="WatchSimulator"
    fi

    export XCODEBUILD_ADDITIONAL_FLAGS="-sdk '$WATCHOSSDK' -destination 'generic/platform=$XCODE_DESTINATION_PLATFORM' PATH='$OLD_PATH' ARCHS='$WATCHOSARCH' ONLY_ACTIVE_ARCH=NO"

    export SYSTEM="darwin"
    export SUBSYSTEM="watchos"
elif [ "$IOSSDK" = "iphoneos" ] || [ "$IOSSDK" = "iphonesimulator" ]; then               # iOS

    export S="$IOSSDK-$IOSARCH-cpython-$PLAIN_VERSION"
    export SDK="$(xcrun --sdk $IOSSDK --show-sdk-path)"

    export ARCHS="$IOSARCH"
    export PLATFORM="$IOSSDK"
    export SDK_NAME="$IOSSDK"
    export ARCHITECTURE="${IOSARCH// /-}"
    export IPHONEOS_DEPLOYMENT_TARGET=13.0
    export MINIMUM_OS_VERSION=13.0
    export ENDIAN="big"

    if [ "$IOSARCH" = "arm64" ]; then
        export ARCHITECTURE_RUST="aarch64"
    else
        export ARCHITECTURE_RUST="x86_64"
    fi

    if [ "$IOSSDK" = "iphoneos" ]; then
        export _PLATFORM=OS64
        export TARGET_TRIPLE="$ARCHITECTURE-apple-ios13.0"
        export XCODE_DESTINATION_PLATFORM="iOS"
        export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-ios --build=$(clang -dumpmachine)"
        export MINVERSION_FLAG="-mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export INFO_PLATFORM_NAME="iPhoneOS"
    elif [ "$IOSSDK" = "iphonesimulator" ]; then
        export _PLATFORM=SIMULATOR64COMBINED
        export TARGET_TRIPLE="$ARCHITECTURE-apple-ios13.0-simulator"
        export XCODE_DESTINATION_PLATFORM="iOS Simulator"
        export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-simulator --build=$(clang -dumpmachine)"
        export MINVERSION_FLAG="-miphonesimulator-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export INFO_PLATFORM_NAME="iPhoneSimulator"
    fi
    
    export XCODEBUILD_ADDITIONAL_FLAGS="-sdk '$IOSSDK' -destination 'generic/platform=$XCODE_DESTINATION_PLATFORM' PATH='$OLD_PATH' ARCHS='$IOSARCH' ONLY_ACTIVE_ARCH=NO"

    export SYSTEM="darwin"
    export SUBSYSTEM="ios"
else                                            # Mac Catalyst

    export ARCHITECTURE="${MAC_CATALYST// /-}"
    export S="maccatalyst-$ARCHITECTURE-cpython-$PLAIN_VERSION"
    export MACOSX_DEPLOYMENT_TARGET=11.0
    export MINIMUM_OS_VERSION=11.0
    export SDK="$(xcrun --sdk macosx --show-sdk-path)"

    export ARCHS="$MAC_CATALYST"
    export PLATFORM="maccatalyst"
    export SDK_NAME="macosx"
    export MINVERSION_FLAG="-mios-version-min=13.1"
    export XCODEBUILD_ADDITIONAL_FLAGS="-sdk $SDK_NAME PATH='$OLD_PATH' SUPPORTS_MACCATALYST='YES' -destination 'platform=macOS,variant=Mac Catalyst' ARCHS='$MAC_CATALYST' ONLY_ACTIVE_ARCH=NO"
    export TARGET_TRIPLE="$ARCHITECTURE-apple-ios13.1-macabi"
    export _PLATFORM="MAC_CATALYST_ARM64"
    export ENDIAN="big"
    if [ "$MAC_CATALYST" = "arm64" ]; then
        export ARCHITECTURE_RUST="aarch64"
    elif [ "$MAC_CATALYST" = "x86_64" ]; then
        export ARCHITECTURE_RUST="x86_64"
    fi
    export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-darwin --build=$(clang -dumpmachine)"
    export INFO_PLATFORM_NAME="MacOSX"
    export SYSTEM="darwin"
    export SUBSYSTEM="macabi"
fi

# Compiler configuration

ARCHFLAGS=""
_ARCHS=""
for arch in $ARCHS; do
    ARCHFLAGS="$ARCHFLAGS -arch $arch"
    _ARCHS="$arch;$_ARCHS"
done
export ARCHS=$_ARCHS
_ARCHS=
export APPLE_TARGET_TRIPLE="$TARGET_TRIPLE"
export CROSS_FILE_PYTHON="$TOOLS_DIR/cross-meson-python.txt"
export CROSS_FILE="$TOOLS_DIR/cross-meson.txt"
export NATIVE_FILE="$TOOLS_DIR/native-meson.txt"
export OLD_PATH="$PATH"
export PATH="$TOOLS_DIR/fortran-ios/bin:$TOOLS_DIR:$PATH"
export CC="$XCRUN --sdk $SDK_NAME clang $ARCHFLAGS"
export CXX="$XCRUN --sdk $SDK_NAME clang++ $ARCHFLAGS"
export LDFLAGS="$ARCHFLAGS -isysroot $SDK -target $TARGET_TRIPLE"
export CPPFLAGS="-target $TARGET_TRIPLE $ARCHFLAGS -isysroot $SDK -UHAVE_FEATURES_H"
export CXXFLAGS="-target $TARGET_TRIPLE $ARCHFLAGS -isysroot $SDK -UHAVE_FEATURES_H"
export CFLAGS="-target $TARGET_TRIPLE $ARCHFLAGS -isysroot $SDK -UHAVE_FEATURES_H"
export CPP="clang -E"
export PIP_REQUIRE_VIRTUALENV=false
export PKG_CONFIG="$(which pkg-config)"
export CMAKE="$(which cmake)"

# Python build stuff

BUILD() {
    LINKER_FLAGS="${PYTHON_LINK//,/ }"
    export CFLAGS="$CFLAGS -I'$PYTHON_HEADERS' -I'$PYTHON_HEADERS/cpython' $LINKER_FLAGS"
    export CXXFLAGS="$CXXFLAGS -I'$PYTHON_HEADERS' -I'$PYTHON_HEADERS/cpython' $LINKER_FLAGS"
    export LDFLAGS="$LDFLAGS $LINKER_FLAGS"
    python -m build --wheel -n "$@"
}

export -f BUILD

CARGO_SETUP() {

    # Install rustup
    export PATH="$TOOLS_DIR/cargo_toolchain:$PATH"
    source $HOME/.cargo/env
    cargo --version || curl https://sh.rustup.rs -sSf | sh
    source $HOME/.cargo/env
    rustup install nightly &> /dev/null

    # Install and configure target
    if [ "$IOSSDK" = "iphoneos" ]; then
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-ios"
    elif [ "$IOSSDK" = "iphonesimulator" ]; then
        if [ "$IOSARCH" = "x86_64" ]; then
            export CARGO_BUILD_TARGET="x86_64-apple-ios"
        else
            export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-ios-sim"
        fi
    elif [ "$TVOSSDK" = "appletvos" ]; then
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-tvos"
    elif [ "$TVOSSDK" = "appletvsimulator" ]; then
        if [ "$TVOSARCH" = "x86_64" ]; then
            export CARGO_BUILD_TARGET="x86_64-apple-tvos"
        else
            export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-tvos-sim"
        fi
    elif [ "$WATCHOSSDK" = "watchos" ]; then
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-watchos"
    elif [ "$WATCHOSSDK" = "watchsimulator" ]; then
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-watchos-sim"
    elif [ "$MAC_CATALYST" = "arm64" ] || [ "$MAC_CATALYST" = "x86_64" ]; then
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-ios-macabi"
    fi
    export PYO3_CROSS_LIB_DIR="$PYTHON_TARGET_PATH"
    export PYO3_PYTHON="$TOOLS_DIR/python3"
    export PYTHON_SYS_EXECUTABLE="$PYO3_PYTHON"
    export RUSTUP_TOOLCHAIN=nightly
    export CARGO_TARGET_CONFIG="$TOOLS_DIR/cargo_toolchain/$CARGO_BUILD_TARGET.json"
    cargo +nightly install cargo-lipo &> /dev/null
    rustup component add rust-src --toolchain nightly-aarch64-apple-darwin

    # watchOS doesn't support cdylib, so we create our own target configuration
    rustc +nightly -Z unstable-options --print target-spec-json --target "$CARGO_BUILD_TARGET" > "$CARGO_TARGET_CONFIG"
    python -c "import json; config_file = open('$CARGO_TARGET_CONFIG', 'r'); config = json.load(config_file); config_file.close(); config['dynamic-linking'] = True; config_file = open('$CARGO_TARGET_CONFIG', 'w'); json.dump(config, config_file); config_file.close()"

    # Replace pyo3 with fork
    find . -name "Cargo.toml" -exec cp "{}" "{}.bak" \;
    find . -name "Cargo.toml" -exec bash -c '(cat {}.bak | insert_patched_pyo3.py) > {}' \;

    # Build std
    find . -name "Cargo.toml" -exec bash -c 'cd "$(dirname "{}")" && cargo +nightly build --target "$CARGO_TARGET_CONFIG" -Zbuild-std' \;

    # failed to read directory <site-directory>/build-details.json: Not a directory (os error 20)
    # you got to be fucking kidding me
    mv "$PYTHON_TARGET_PATH/build-details.json" "$PYTHON_TARGET_PATH/_build-details.json"
}

export -f CARGO_SETUP

RUST_BUILD() {
    mkdir ".cargo"
    echo '[unstable]' >> ".cargo/config.toml"
    echo 'build-std = ["std"]' >> ".cargo/config.toml"

    CARGO_SETUP
    BUILD

    mv "$PYTHON_TARGET_PATH/_build-details.json" "$PYTHON_TARGET_PATH/build-details.json"
    find . -name "Cargo.toml" -exec bash -c 'rm {} && mv {}.bak {}' \;
    
    rm -rf ".cargo"
}

export -f RUST_BUILD

MATURIN_BUILD() {
    CARGO_SETUP

    # Install patched maturin
    python -m pip install git+https://git.gatit.es/pyto/maturin.git@main

    # Build
    python -m maturin build -v --interpreter "$PYO3_PYTHON" "$@" \
    --release --target "$CARGO_BUILD_TARGET" \
    -Zbuild-std "$@"

    # Restore files
    mv "$PYTHON_TARGET_PATH/_build-details.json" "$PYTHON_TARGET_PATH/build-details.json"
    find . -name "Cargo.toml" -exec bash -c 'rm {} && mv {}.bak {}' \;
}

export -f MATURIN_BUILD

MESON_BUILD_PYTHON() {

    # Create meson configuration
    cp "$CROSS_FILE_PYTHON" "$CROSS_FILE_PYTHON.temp"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$PYTHON_HEADERS' "$PYTHON_HEADERS"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$PYTHON_LINK' "$PYTHON_LINK"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$SDK_NAME' "$SDK_NAME"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$SDK_PATH' "$SDK"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$ARCH' "$ARCHITECTURE"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$TARGET_TRIPLE' "$TARGET_TRIPLE"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$MINVERSION_FLAG' "$MINVERSION_FLAG"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$ROOT' "$(dirname "$(dirname "$SDK")")"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$CPU' "$ARCHITECTURE_RUST"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$ENDIAN' "$ENDIAN"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$ADDITIONAL_MESON_PROPERTIES' "$ADDITIONAL_MESON_PROPERTIES"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$ADDITIONAL_COMPILER_FLAGS' "$ADDITIONAL_COMPILER_FLAGS"
    if [ -z "$SUBSYSTEM" ]; then
        "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" "\nsubsystem = '\$SUBSYSTEM'" ""
    else
        "$TOOLS_DIR/replace.py" "$CROSS_FILE_PYTHON.temp" '$SUBSYSTEM' "$SUBSYSTEM"
    fi

    # Build
    export MESON_FORCE_BACKTRACE=1
    if [ -z "$MAC_CATALYST" ]; then
        python -m build -n \
            -Csetup-args="--cross-file=${CROSS_FILE_PYTHON}.temp" \
            "$@"
    else
        # Not cross compiling when building for Mac Catalyst
        python -m build -n "$@"
    fi
    
    rm "$CROSS_FILE_PYTHON.temp"
}

export -f MESON_BUILD_PYTHON

if [ -z "$BUILD_SCRIPT" ]; then
    echo > /dev/null
else
    bash "$BUILD_SCRIPT"
fi
