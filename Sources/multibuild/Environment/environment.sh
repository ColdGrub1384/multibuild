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

export TOOLS_DIR="$PWD"

if [ -z "$IOSSDK" ] && [ -z "$MAC_CATALYST" ] && [ -z "$WATCHOSSDK" ] && [ -z "$TVOSSDK" ]; then # Other platforms

    exit 1

elif [ "$TVOSSDK" = "appletvos" ] || [ "$TVOSSDK" = "appletvsimulator" ]; then # tvOS

    export ARCHITECTURE="${TVOSARCH// /-}"
    export S="$TVOSSDK-$ARCHITECTURE-cpython-$PLAIN_VERSION"
    export SDK="$(xcrun --sdk $TVOSSDK --show-sdk-path)"
    export CROSS_FILE="$TOOLS_DIR/cross-meson.txt"

    export PLATFORM="$TVOSSDK"
    export SDK_NAME="$TVOSSDK"
    export ARCHS="$TVOSARCH"
    export TVOS_DEPLOYMENT_TARGET=13.0
    export MINIMUM_OS_VERSION=13.0

    export _PYTHON_HOST_PLATFORM=appletvos-$ARCHITECTURE

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
    export CROSS_FILE="$TOOLS_DIR/cross-meson.txt"

    export ARCHS="$WATCHOSARCH"
    export PLATFORM="$WATCHOSSDK"
    export SDK_NAME="$WATCHOSSDK"
    export ARCHITECTURE="${WATCHOSARCH// /-}"
    export WATCHOS_DEPLOYMENT_TARGET=6.0
    export MINIMUM_OS_VERSION=6.0
    export _PYTHON_HOST_PLATFORM=watchos-$ARCHITECTURE

    if [ "$WATCHOSARCH" = "arm64" ]; then
        export ARCHITECTURE_RUST="aarch64"
    elif [ "$WATCHOSARCH" = "arm64_32" ]; then
        export ARCHITECTURE_RUST="arm64_32"
    elif [ "$WATCHOSARCH" = "armv7k" ]; then
        export ARCHITECTURE_RUST="armv7k"
    else
        export ARCHITECTURE_RUST="x86_64"
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
    export CROSS_FILE="$TOOLS_DIR/cross-meson.txt"

    export ARCHS="$IOSARCH"
    export PLATFORM="$IOSSDK"
    export SDK_NAME="$IOSSDK"
    export ARCHITECTURE="${IOSARCH// /-}"
    export IPHONEOS_DEPLOYMENT_TARGET=13.0
    export MINIMUM_OS_VERSION=13.0
    export _PYTHON_HOST_PLATFORM=ios-$ARCHITECTURE

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
    export _PYTHON_HOST_PLATFORM="ios-macabi-$ARCHITECTURE"
    export _PLATFORM="MAC_CATALYST_ARM64"
    if [ "$MAC_CATALYST" = "arm64" ]; then
        export ARCHITECTURE_RUST="aarch64"
    elif [ "$MAC_CATALYST" = "x86_64" ]; then
        export ARCHITECTURE_RUST="x86_64"
    fi
    export AUTOGEN_FLAGS="--host=$ARCHITECTURE-apple-darwin --build=$(clang -dumpmachine)"
    export INFO_PLATFORM_NAME="MacOSX"
    export SYSTEM="darwin"
    export SUBSYSTEM=""
fi

ARCHFLAGS=""
_ARCHS=""
for arch in $ARCHS; do
    ARCHFLAGS="$ARCHFLAGS -arch $arch"
    _ARCHS="$arch;$_ARCHS"
done
export ARCHS=$_ARCHS
_ARCHS=
export APPLE_TARGET_TRIPLE="$TARGET_TRIPLE"

export BUILD_DIR="$PWD/build/lib.$S"

export OLD_PATH="$PATH"
export PATH="$TOOLS_DIR/fortran-ios/bin:$TOOLS_DIR:$PATH"
export LD="$TOOLS_DIR/ld"
export CC="$XCRUN --sdk $SDK_NAME clang -target $TARGET_TRIPLE $ARCHFLAGS"
export CXX="$XCRUN --sdk $SDK_NAME clang -target $TARGET_TRIPLE $ARCHFLAGS -lstdc++"
export CPP="$CXX"
export LDFLAGS="$ARCHFLAGS -isysroot $SDK"
export CPPFLAGS="-target $TARGET_TRIPLE $ARCHFLAGS -isysroot $SDK -UHAVE_FEATURES_H"
export CXXFLAGS="-target $TARGET_TRIPLE $ARCHFLAGS -isysroot $SDK -UHAVE_FEATURES_H'"
export CFLAGS="-target $TARGET_TRIPLE $ARCHFLAGS -isysroot $SDK -UHAVE_FEATURES_H"
export CPP="clang -E"

export PIP_REQUIRE_VIRTUALENV=false
alias PYTHON="$(which "python$VERSION")"
alias DEPS_UTIL="$TOOLS_DIR/deps_util.py '$SITE_DIR' '$(which "python$VERSION")'"
alias COPY_SCRIPTS="$TOOLS_DIR/copy-scripts.sh"
alias COPY_EGGS="$TOOLS_DIR/copy-eggs.sh $VERSION"
alias COPY_DIST="$TOOLS_DIR/copy-dist.sh $VERSION"

MAKE_FRAMEWORKS() {
    "$(which python3)" "$TOOLS_DIR/make_frameworks.py" "$VERSION" "$dir" "$1"
    BUILD_LIBRARY="$dir" "$TOOLS_DIR/make-fat-frameworks.sh"
}

BUILD() {
    find . -name '*.dist-info' -delete
    find . -name '*.egg-info' -delete

    flags="$LDFLAGS"
    export LDFLAGS="$LDFLAGS -framework Python$PLAIN_VERSION"

    mkdir -p build/lib.$S
    PYTHON -m pip install . --no-deps --upgrade -t "$BUILD_DIR" $@
    
    export LDFLAGS="$flags"
}

CARGO_SETUP() {
    source $HOME/.cargo/env
    cargo --version || curl https://sh.rustup.rs -sSf | sh
    source $HOME/.cargo/env
    export PATH="$(pwd):$PATH"
    rustup install nightly
    
    if [ "$IOSSDK" = "iphoneos" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-ios"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-ios"
    elif [ "$IOSSDK" = "iphonesimulator" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-ios-sim"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-ios-sim"
    elif [ "$TVOSSDK" = "appletvos" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-tvos"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-tvos"
    elif [ "$TVOSSDK" = "appletvsimulator" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-tvos-sim"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-tvos-sim"
    elif [ "$WATCHOS" = "watchos" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-watchos"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-watchos"
    elif [ "$WATCHOS" = "watchsimulator" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-watchos-sim"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-watchos-sim"
    elif [ "$MAC_CATALYST" = "arm64" ] || [ "$MAC_CATALYST" = "x86_64" ]; then
        rustup +nightly target add "$ARCHITECTURE_RUST-apple-ios-macabi"
        export CARGO_BUILD_TARGET="$ARCHITECTURE_RUST-apple-ios-macabi"
    fi
        
    cargo +nightly install cargo-lipo

    # export OPENSSL_NO_PKG_CONFIG=1
    # export OPENSSL_STATIC=1
    # export OPENSSL_INCLUDE_DIR="$OPENSSL_HEADERS"
    # export OPENSSL_LIB_DIR="$OPENSSL_LIB"
    # export PYO3_CROSS_LIB_DIR="$(pwd)/../cpython/build/python$VERSION"
}

RUST_BUILD() {
    CARGO_SETUP
    mv "$TOOLS_DIR/cc" "$TOOLS_DIR/_cc"
    mv "$TOOLS_DIR/c++" "$TOOLS_DIR/_c++"
    
    flags="$LDFLAGS"
    export LDFLAGS="$LDFLAGS -framework Python$PLAIN_VERSION"
    
    BUILD
    
    export LDFLAGS="$flags"
    
    mv "$TOOLS_DIR/_cc" "$TOOLS_DIR/cc"
    mv "$TOOLS_DIR/_c++" "$TOOLS_DIR/c++"
}

MATURIN_BUILD() {
    find . -name '*.dist-info' -delete
    find . -name '*.egg-info' -delete

    CARGO_SETUP

    flags="$LDFLAGS"
    export LDFLAGS="$LDFLAGS -framework Python$PLAIN_VERSION"
    
    if [ -z "$MAC_CATALYST" ]; then
        target="$ARCHITECTURE-apple-ios"
    else
        target="$ARCHITECTURE-apple-ios-macabi"
    fi
    
    LD= CFLAGS= CPPFLAGS= CXXFLAGS= CC= CXX= CPP= PATH="$TOOLS_DIR/maturin_toolchain:$PATH" maturin build "$@" --release --target $target
    
    export LDFLAGS="$flags"
    
    pushd target/wheels
    wheel="$PWD/*.whl"
    popd
    mkdir -p "build/lib.$S"
    pushd "build/lib.$S"
    rm -rf *
    unzip "$wheel"
    popd
}

MESON_BUILD() {

    find . -name '*.dist-info' -delete
    find . -name '*.egg-info' -delete

    #export CC=
    #export CXX=
    #export LD=
    export PKG_CONFIG="$(which pkg-config)"
    export PKG_CONFIG_PATH="$(dirname "$(which "python$VERSION")")/../lib/pkgconfig"

    cp "$CROSS_FILE" "$CROSS_FILE.temp"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$PYTHON_HEADERS' "$PYTHON_HEADERS"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$PYTHON_LIB' "$PYTHON_LIB"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$PYTHON_FRAMEWORK' "Python$PLAIN_VERSION"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$SDK_NAME' "$SDK_NAME"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$SDK_PATH' "$SDK"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ARCH' "$ARCHITECTURE"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$MINVERSION_FLAG' "$MINVERSION_FLAG"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ROOT' "$(dirname "$(dirname "$SDK")")"
    "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$CPU' "$ARCHITECTURE_RUST"
    if [ -z "$SUBSYSTEM" ]; then
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" "\nsubsystem = '\$SUBSYSTEM'" ""
    else
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$SUBSYSTEM' "$SUBSYSTEM"
    fi
    
    if [ -z "$MAC_CATALYST" ]; then
    PYTHON -m build --config-setting "setup-args=--cross-file=${CROSS_FILE}.temp" $@
    else
    PYTHON -m build $@
    fi
    
    pushd dist
    wheel="$PWD/*.whl"
    popd
    mkdir -p "build/lib.$S"
    pushd "build/lib.$S"
    rm -rf *
    unzip "$wheel"
    popd

    rm "$CROSS_FILE.temp"
}

COPY_BIN() {
    pushd "$BUILD_DIR"
    bins="$(echo bin/*)"
    popd
    COPY_SCRIPTS $bins
}

INSTALL_DEPS_EGG() {
    find . -name "*.egg_info" -print0 | grep -qz . || PYTHON setup.py egg_info
    EGG="$(find . -name "*.egg-info" | tail -n 1)"
    DEPS_UTIL install -r "$EGG/requires.txt"
}

INSTALL_DEPS_DIST() {
    DIST="$(find . -name "*.dist-info" | tail -n 1)"
    DEPS_UTIL install -r "$DIST/METADATA"
}

INSTALL_DEPS() {
    find . -name "*.egg_info" -print0 | grep -qz . && INSTALL_DEPS_EGG && return
    find . -name "*.dist-info" -print0 | grep -qz . && INSTALL_DEPS_DIST && return
}

# Register installed top directories, back them up progressively before each pip install here or from $SITE_DIR/install.sh
REGISTER() {
    find . -name "*.egg_info" -print0 | grep -qz . && REGISTER_EGG && return
    find . -name "*.dist-info" -print0 | grep -qz . && REGISTER_DIST && return
}

REGISTER_EGG() {
    EGG="$(find . -name "*.egg-info" | tail -n 1)"
    TOP_LEVEL="$(cat "$EGG"/top_level.txt)"
    mkdir -p ../toplevel
    
    for i in $TOP_LEVEL; do
        file="$SITE_DIR/$i"
        [ ! -e $file ] && file="$file.py"
        rm -rf "../toplevel/$(basename $file)"
        [ -e $file ] && cp -r $file ../toplevel
    done
        
    for pkg in ../toplevel/*; do
        name="$(basename "$pkg")"
        [ ! -e "../toplevel/$name" ] && name="$name.py"
        rm -rf "$SITE_DIR/$name"
        cp -r "../toplevel/$name" "$SITE_DIR/$name"
    done
}

REGISTER_DIST() {
    TOP_LEVEL="$(ls $BUILD_DIR)"
    mkdir -p ../toplevel
    
    for i in $TOP_LEVEL; do
        file="$SITE_DIR/$i"
        [ ! -e $file ] && file="$file.py"
        rm -rf "../toplevel/$(basename $file)"
        [ -e $file ] && cp -r $file ../toplevel
    done
        
    for pkg in ../toplevel/*; do
        name="$(basename "$pkg")"
        [ ! -e "../toplevel/$name" ] && name="$name.py"
        rm -rf "$SITE_DIR/$name"
        cp -r "../toplevel/$name" "$SITE_DIR/$name"
    done
}

trap REGISTER EXIT

if [ -z "$BUILD_SCRIPT" ]; then
    echo > /dev/null
else
    bash "$BUILD_SCRIPT"
fi