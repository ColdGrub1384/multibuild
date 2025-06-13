#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")/../Dependencies"
TOOLS_DIR="$PWD/../Resources"
ROOT="$PWD/../.."

all_platforms() {
    prefix="$PWD"
    plats=""
    if [ -e "$prefix/$1/build/iphoneos.arm64/$2" ]; then
        plats="$prefix/$1/build/iphoneos.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/maccatalyst.arm64/$2" ]; then
        plats="$plats $prefix/$1/build/maccatalyst.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/maccatalyst.x86_64/$2" ]; then
        plats="$plats $prefix/$1/build/maccatalyst.x86_64/$2"
    fi
    if [ -e "$prefix/$1/build/watchos.arm64_32/$2" ]; then
        plats="$plats $prefix/$1/build/watchos.arm64_32/$2"
    fi
    if [ -e "$prefix/$1/build/watchos.arm64/$2" ]; then
        plats="$plats $prefix/$1/build/watchos.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/watchos.armv7k/$2" ]; then
        plats="$plats $prefix/$1/build/watchos.armv7k/$2"
    fi
    if [ -e "$prefix/$1/build/appletvos.arm64/$2" ]; then
        plats="$plats $prefix/$1/build/appletvos.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/iphonesimulator.arm64/$2" ]; then
        plats="$plats $prefix/$1/build/iphonesimulator.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/iphonesimulator.x86_64/$2" ]; then
        plats="$plats $prefix/$1/build/iphonesimulator.x86_64/$2"
    fi
    if [ -e "$prefix/$1/build/watchsimulator.arm64/$2" ]; then
        plats="$plats $prefix/$1/build/watchsimulator.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/watchsimulator.x86_64/$2" ]; then
        plats="$plats $prefix/$1/build/watchsimulator.x86_64/$2"
    fi
    if [ -e "$prefix/$1/build/appletvsimulator.arm64/$2" ]; then
        plats="$plats $prefix/$1/build/appletvsimulator.arm64/$2"
    fi
    if [ -e "$prefix/$1/build/appletvsimulator.x86_64/$2" ]; then
        plats="$plats $prefix/$1/build/appletvsimulator.x86_64/$2"
    fi
    
    echo $plats
}

platform() {
    echo "-force_load '$2/build/$1/$3'"
}

PACKAGE_FRAMEWORKS() {
    IOS_FWORKS=""
    IOS_BINARY_NAME=""
    
    TVOS_FWORKS=""
    TVOS_BINARY_NAME=""
    
    IOS_SIMULATOR_FWORKS=""
    IOS_SIMULATOR_BINARIES=""
    IOS_SIMULATOR_BINARY_NAME=""
    IOS_SIMULATOR_STUB_FRAMEWORK=""
    ios_simulator_binaries_found="no"
    
    WATCH_SIMULATOR_FWORKS=""
    WATCH_SIMULATOR_BINARIES=""
    WATCH_SIMULATOR_BINARY_NAME=""
    WATCH_SIMULATOR_STUB_FRAMEWORK=""
    watch_simulator_binaries_found="no"
    
    WATCH_FWORKS=""
    WATCH_BINARIES=""
    WATCH_BINARY_NAME=""
    WATCH_STUB_FRAMEWORK=""
    watch_binaries_found="no"
    
    TVOS_SIMULATOR_FWORKS=""
    TVOS_SIMULATOR_BINARIES=""
    TVOS_SIMULATOR_BINARY_NAME=""
    TVOS_SIMULATOR_STUB_FRAMEWORK=""
    tvos_simulator_binaries_found="no"
    
    MAC_FWORKS=""
    MAC_BINARIES=""
    MAC_STUB_FRAMEWORK=""
    MAC_BINARY_NAME=""
    mac_binaries_found="no"
    
    FILENAME=""
    
    FRAMEWORK_NAME=""
    ver=""

    for src in `eval echo $1`; do
        FILENAME="$(basename $src)"
        FRAMEWORK_NAME="${FILENAME%.framework}"
        if [[ "$FRAMEWORK_NAME" =~ "-abi3" ]]; then
            FRAMEWORK_NAME="${FRAMEWORK_NAME/"-abi3"/"-cp$PLAIN_VERSION"}"
        fi
        if [[ $src =~ "maccatalyst." ]]; then
            mac_binaries_found="yes"
            if [ -d "$src/Versions/A" ]; then
                ver="A"
            elif [ -d "$src/Versions/Current" ]; then
                ver="Current"
            fi
            for file in "$src/Versions/$ver"/*; do
                if [[ "$file"=*?.so ]] || [ -x "$file" ] && [ -f "$file" ]; then
                    MAC_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Versions/Current/Resources/Info.plist")"
                    if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                        install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/Versions/$ver/$MAC_BINARY_NAME"
                    fi
                    mv "$src/Versions/$ver/$MAC_BINARY_NAME" "$src/Versions/$ver/$FRAMEWORK_NAME"
                    rm "$src/$MAC_BINARY_NAME"
                    pushd "$src"
                    ln -s "Versions/$ver/$FRAMEWORK_NAME" "$FRAMEWORK_NAME"
                    popd
                    MAC_BINARIES="$MAC_BINARIES '$src/Versions/$ver/$FRAMEWORK_NAME'"
                    
                    "$TOOLS_DIR/replace.py" "$src/Versions/$ver/Resources/Info.plist" "$MAC_BINARY_NAME" "$FRAMEWORK_NAME"
                fi
            done
            MAC_STUB_FRAMEWORK="$src"
        elif [[ $src =~ "iphonesimulator." ]]; then
            ios_simulator_binaries_found="yes"
            IOS_SIMULATOR_FWORKS="$IOS_SIMULATOR_FWORKS -framework '$src'"
            IOS_SIMULATOR_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Info.plist")"
            if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/$IOS_SIMULATOR_BINARY_NAME"
            fi
            mv "$src/$IOS_SIMULATOR_BINARY_NAME" "$src/$FRAMEWORK_NAME"
            IOS_SIMULATOR_BINARIES="$IOS_SIMULATOR_BINARIES $src/$FRAMEWORK_NAME"
            "$TOOLS_DIR/replace.py" "$src/Info.plist" "$IOS_SIMULATOR_BINARY_NAME" "$FRAMEWORK_NAME"
            IOS_SIMULATOR_STUB_FRAMEWORK="$src"
        elif [[ $src =~ "iphoneos." ]]; then
            IOS_FWORKS="$IOS_FWORKS -framework '$src'"
            IOS_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Info.plist")"
            if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/$IOS_BINARY_NAME"
            fi
            mv "$src/$IOS_BINARY_NAME" "$src/$FRAMEWORK_NAME"
            "$TOOLS_DIR/replace.py" "$src/Info.plist" "$IOS_BINARY_NAME" "$FRAMEWORK_NAME"
        elif [[ $src =~ "appletvsimulator." ]]; then
            tvos_simulator_binaries_found="yes"
            TVOS_SIMULATOR_FWORKS="$TVOS_SIMULATOR_FWORKS -framework '$src'"
            TVOS_SIMULATOR_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Info.plist")"
            if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/$TVOS_SIMULATOR_BINARY_NAME"
            fi
            mv "$src/$TVOS_SIMULATOR_BINARY_NAME" "$src/$FRAMEWORK_NAME"
            TVOS_SIMULATOR_BINARIES="$TVOS_SIMULATOR_BINARIES $src/$FRAMEWORK_NAME"
            "$TOOLS_DIR/replace.py" "$src/Info.plist" "$TVOS_SIMULATOR_BINARY_NAME" "$FRAMEWORK_NAME"
            TVOS_SIMULATOR_STUB_FRAMEWORK="$src"
        elif [[ $src =~ "appletvos." ]]; then
            TVOS_FWORKS="$TVOS_FWORKS -framework '$src'"
            TVOS_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Info.plist")"
            if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/$TVOS_BINARY_NAME"
            fi
            mv "$src/$TVOS_BINARY_NAME" "$src/$FRAMEWORK_NAME"
            "$TOOLS_DIR/replace.py" "$src/Info.plist" "$TVOS_BINARY_NAME" "$FRAMEWORK_NAME"
        elif [[ $src =~ "watchsimulator." ]]; then
            watch_simulator_binaries_found="yes"
            WATCH_SIMULATOR_FWORKS="$WATCH_SIMULATOR_FWORKS -framework '$src'"
            WATCH_SIMULATOR_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Info.plist")"
            if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/$WATCH_SIMULATOR_BINARY_NAME"
            fi
            mv "$src/$WATCH_SIMULATOR_BINARY_NAME" "$src/$FRAMEWORK_NAME"
            WATCH_SIMULATOR_BINARIES="$WATCH_SIMULATOR_BINARIES $src/$FRAMEWORK_NAME"
            "$TOOLS_DIR/replace.py" "$src/Info.plist" "$WATCH_SIMULATOR_BINARY_NAME" "$FRAMEWORK_NAME"
            WATCH_SIMULATOR_STUB_FRAMEWORK="$src"
        elif [[ $src =~ "watchos." ]]; then
            watch_binaries_found="yes"
            WATCH_FWORKS="$WATCH_FWORKS -framework '$src'"
            WATCH_BINARY_NAME="$(/usr/libexec/PlistBuddy -c "print CFBundleExecutable" "$src/Info.plist")"
            if [[ $src =~ "-cp$PLAIN_VERSION.framework" ]]; then
                install_name_tool -id "@rpath/PythonFrameworks.framework/PythonFrameworks" "$src/$WATCH_BINARY_NAME"
            fi
            mv "$src/$WATCH_BINARY_NAME" "$src/$FRAMEWORK_NAME"
            WATCH_BINARIES="$WATCH_BINARIES $src/$FRAMEWORK_NAME"
            "$TOOLS_DIR/replace.py" "$src/Info.plist" "$WATCH_BINARY_NAME" "$FRAMEWORK_NAME"
            WATCH_STUB_FRAMEWORK="$src"
        fi
    done
    
    if [ "$mac_binaries_found" = "yes" ]; then
        mkdir -p "maccatalyst.universal"
        cp -R "$MAC_STUB_FRAMEWORK" "maccatalyst.universal/$FILENAME"
        rm -rf "$ROOT/$FRAMEWORK_NAME.xcframework"
        eval lipo -create "$MAC_BINARIES" -output "maccatalyst.universal/$FILENAME/Versions/$ver/$FRAMEWORK_NAME"
        MAC_FWORKS="-framework 'maccatalyst.universal/$FRAMEWORK_NAME.framework'"
    fi
    
    if [ "$ios_simulator_binaries_found" = "yes" ]; then
        mkdir -p "iphonesimulator.universal"
        cp -R "$IOS_SIMULATOR_STUB_FRAMEWORK" "iphonesimulator.universal/$FILENAME"
        rm -rf "$ROOT/$FRAMEWORK_NAME.xcframework"
        eval lipo -create "$IOS_SIMULATOR_BINARIES" -output "iphonesimulator.universal/$FILENAME/$FRAMEWORK_NAME"
        IOS_SIMULATOR_FWORKS="-framework 'iphonesimulator.universal/$FRAMEWORK_NAME.framework'"
    fi
    
    if [ "$tvos_simulator_binaries_found" = "yes" ]; then
        mkdir -p "appletvsimulator.universal"
        cp -R "$TVOS_SIMULATOR_STUB_FRAMEWORK" "appletvsimulator.universal/$FILENAME"
        rm -rf "$ROOT/$FRAMEWORK_NAME.xcframework"
        eval lipo -create "$TVOS_SIMULATOR_BINARIES" -output "appletvsimulator.universal/$FILENAME/$FRAMEWORK_NAME"
        TVOS_SIMULATOR_FWORKS="-framework 'appletvsimulator.universal/$FRAMEWORK_NAME.framework'"
    fi
    
    if [ "$watch_binaries_found" = "yes" ]; then
        mkdir -p "watchos.universal"
        cp -R "$WATCH_STUB_FRAMEWORK" "watchos.universal/$FILENAME"
        rm -rf "$ROOT/$FRAMEWORK_NAME.xcframework"
        eval lipo -create "$WATCH_BINARIES" -output "watchos.universal/$FILENAME/$FRAMEWORK_NAME"
        WATCH_FWORKS="-framework 'watchos.universal/$FRAMEWORK_NAME.framework'"
    fi
    
    if [ "$watch_simulator_binaries_found" = "yes" ]; then
        mkdir -p "watchsimulator.universal"
        cp -R "$WATCH_SIMULATOR_STUB_FRAMEWORK" "watchsimulator.universal/$FILENAME"
        rm -rf "$ROOT/$FRAMEWORK_NAME.xcframework"
        eval lipo -create "$WATCH_SIMULATOR_BINARIES" -output "watchsimulator.universal/$FILENAME/$FRAMEWORK_NAME"
        WATCH_SIMULATOR_FWORKS="-framework 'watchsimulator.universal/$FRAMEWORK_NAME.framework'"
    fi
    
    eval xcodebuild -create-xcframework $IOS_FWORKS $MAC_FWORKS $IOS_SIMULATOR_FWORKS $WATCH_FWORKS $WATCH_SIMULATOR_FWORKS $TVOS_FWORKS $TVOS_SIMULATOR_FWORKS -output "$ROOT/$FRAMEWORK_NAME.xcframework"
    rm -rf "$FILENAME"
    rm -rf "watchos.universal"
    rm -rf "appletvsimulator.universal"
    rm -rf "watchsimulator.universal"
    rm -rf "iphonesimulator.universal"
    rm -rf "maccatalyst.universal"
}

CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES() {

    armv7k_binaries=""
    arm64_32_binaries=""
    arm64_binaries=""
    x86_64_binaries=""
    all_binaries=""
    
    mac_catalyst="no"
    
    headers=""
    minimum_os_version=""
    
    linker_flags="-dynamiclib -framework CoreFoundation -framework Security -liconv -lz -lc++ -install_name @rpath/$4.framework/$4"
    echo "int _library_main() { return 0; }" > "_library_main.c"
    
    link_ios_system="no"
    link_libssh2="no"
    link_openssl="no"
    link_gss="no"
    
    xcframework_platform=""
    
    for binary in ${1}; do
    
        if [[ "$binary" =~ "libgit2.a" ]]; then
            link_ios_system="yes"
            link_libssh2="yes"
            link_openssl="yes"
            link_gss="yes"
        elif [[ "$binary" =~ "libssh2.a" ]]; then
            link_openssl="yes"
        fi
    
        if [[ "$binary" =~ ".armv7k" ]]; then
            armv7k_binaries="$armv7k_binaries -force_load $binary"
        elif [[ "$binary" =~ ".arm64_32" ]]; then
            arm64_32_binaries="$arm64_32_binaries -force_load $binary"
        elif [[ "$binary" =~ ".arm64" ]]; then
            maccatalyst_arch="arm64"
            arm64_binaries="$arm64_binaries -force_load $binary"
        elif [[ "$binary" =~ ".x86_64" ]]; then
            maccatalyst_arch="x86_64"
            x86_64_binaries="$x86_64_binaries -force_load $binary"
        fi
    
        if [[ "$binary" =~ "maccatalyst." ]]; then
            mac_catalyst="yes"
            minimum_os_version="11.0"
            linker_flags="$linker_flags -target $maccatalyst_arch-apple-ios13.1-macabi"
            xcframework_platform="ios-arm64_x86_64-maccatalyst"
        elif [[ "$binary" =~ "iphoneos." ]] || [[ "$binary" =~ "iphonesimulator." ]] || [[ "$binary" =~ "appletvos." ]] || [[ "$binary" =~ "appletvsimulator." ]]; then
            minimum_os_version="14.0"
            if [[ "$binary" =~ "iphoneos." ]]; then
                linker_flags="$linker_flags -miphoneos-version-min=14.0"
                xcframework_platform="ios-arm64"
            elif [[ "$binary" =~ "iphonesimulator" ]]; then
                linker_flags="$linker_flags -miphonesimulator-version-min=14.0"
                xcframework_platform="ios-arm64_x86_64-simulator"
            elif [[ "$binary" =~ "appletvos" ]]; then
                link_gss="no"
                linker_flags="$linker_flags -mappletvos-version-min=14.0"
                xcframework_platform="tvos-arm64"
            elif [[ "$binary" =~ "appletvsimulator" ]]; then
                link_gss="no"
                linker_flags="$linker_flags -mappletvsimulator-version-min=14.0"
                xcframework_platform="tvos-arm64_x86_64-simulator"
            fi
        elif [[ "$binary" =~ "watchos." ]] || [[ "$binary" =~ "watchsimulator." ]]; then
            link_gss="no"
            minimum_os_version="7.0"
            if [[ "$binary" =~ "watchos" ]]; then
                linker_flags="$linker_flags -mwatchos-version-min=7.0"
                xcframework_platform="watchos-arm64_arm64_32_armv7k"
            else
                linker_flags="$linker_flags -mwatchsimulator-version-min=7.0"
                xcframework_platform="watchos-arm64_x86_64-simulator"
            fi
        fi
    done
    
    if [[ "$link_ios_system" = "yes" ]]; then
        linker_flags="$linker_flags -F'$ROOT/ios_system.xcframework/$xcframework_platform' -framework ios_system"
    fi
    if [[ "$link_openssl" = "yes" ]]; then
        linker_flags="$linker_flags -F'$ROOT/openssl.xcframework/$xcframework_platform' -framework openssl"
    fi
    if [[ "$link_libssh2" = "yes" ]]; then
        linker_flags="$linker_flags -F'$ROOT/ssh2.xcframework/$xcframework_platform' -framework ssh2"
    fi
    if [[ "$link_gss" = "yes" ]]; then
        linker_flags="$linker_flags -framework GSS"
    fi
    
    for include in ${2}; do
        headers="$include"
        break
    done
    
    if [ -z "$armv7k_binaries" ]; then
        :
    else
        all_binaries="$all_binaries $4.armv7k"
        eval xcrun -sdk "$3" clang -arch armv7k "_library_main.c" $armv7k_binaries $linker_flags -o "$4.armv7k"
    fi

    if [ -z "$arm64_32_binaries" ]; then
        :
    else
        all_binaries="$all_binaries $4.arm64_32"
        eval xcrun -sdk "$3" clang -arch arm64_32 "_library_main.c" $arm64_32_binaries $linker_flags -o "$4.arm64_32"
    fi

    if [ -z "$arm64_binaries" ]; then
        :
    else
        all_binaries="$all_binaries $4.arm64"
        eval xcrun -sdk "$3" clang -arch arm64 "_library_main.c" $arm64_binaries $linker_flags -o "$4.arm64"
    fi

    if [ -z "$x86_64_binaries" ]; then
        :
    else
        all_binaries="$all_binaries $4.x86_64"
        eval xcrun -sdk "$3" clang -arch x86_64 "_library_main.c" $x86_64_binaries $linker_flags -o "$4.x86_64"
    fi
    
    eval lipo -create $all_binaries -output "$4"
    rm -f "$4.armv7k" "$4.arm64_32" "$4.arm64" "$4.x86_64"
    
    info_plist="$PWD/Info.plist"
    cp "$ROOT/Extensions/Resources/pythonDependencies-Info.plist" "$info_plist"
    "$ROOT/Extensions/Resources/replace.py" "$info_plist" "%name%" "$4"
    "$ROOT/Extensions/Resources/replace.py" "$info_plist" "%os_version%" "$minimum_os_version"
    "$ROOT/Extensions/Resources/replace.py" "$info_plist" "%platform%" "$INFO_PLATFORM_NAME"
    
    if [ "$mac_catalyst" = "yes" ]; then
        mkdir -p "$4.framework/Versions/A/Resources"
        pushd "$4.framework/Versions" > /dev/null
        ln -s "A" "Current"
        popd > /dev/null
        mv "$4" "$4.framework/Versions/A/"
        pushd "$4.framework" > /dev/null
        ln -s "Versions/Current/$4" "$4"
        ln -s "Versions/Current/Resources" "Resources"
        if [ -z "$headers" ]; then
            :
        else
            cp -r "$headers" "Versions/Current/Headers"
            ln -s "Versions/Current/Headers" "Headers"
            rm Versions/Current/Headers/*.in &> /dev/null
        fi
        mv $info_plist "Versions/Current/Resources/"
        
        popd > /dev/null
    else
        mkdir -p "$4.framework"
        mv "$4" "$4.framework/"
        mv $info_plist "$4.framework/"
        if [ -z "$headers" ]; then
            :
        else
            cp -r "$headers" "$4.framework/Headers"
            rm "$4.framework"/Headers/*.in &> /dev/null
        fi
    fi
    
    rm "_library_main.c"
    
    echo "$4.framework"
}

# Dependencies

if [ -z "$BUILD_LIBRARY" ]; then
    
    mkdir "build_iphoneos"
    mkdir "build_iphonesimulator"
    mkdir "build_watchos"
    mkdir "build_watchsimulator"
    mkdir "build_appletvos"
    mkdir "build_appletvsimulator"
    mkdir "build_maccatalyst"
    
    rm -rf "$ROOT/openssl.xcframework" "$ROOT/ffi.xcframework" "$ROOT/mpdec.xcframework" "$ROOT/bz2.xcframework" "$ROOT/lzma.xcframework" "$ROOT/ssh2.xcframework" "$ROOT/git2.xcframework"
    
    ## openssl ##
    
    openssl_libs="$(all_platforms "openssl" "lib/libssl.a") $(all_platforms "openssl" "lib/libcrypto.a")"
    openssl_headers="$(all_platforms "openssl" "include/openssl")"

    openssl_iphoneos_binaries=""
    openssl_iphonesimulator_binaries=""
    openssl_watchos_binaries=""
    openssl_watchsimulator_binaries=""
    openssl_appletvos_binaries=""
    openssl_appletvsimulator_binaries=""
    openssl_maccatalyst_binaries=""
    
    for lib in $openssl_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            openssl_iphoneos_binaries="$openssl_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            openssl_iphonesimulator_binaries="$openssl_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            openssl_watchos_binaries="$openssl_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            openssl_watchsimulator_binaries="$openssl_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            openssl_appletvos_binaries="$openssl_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            openssl_appletvsimulator_binaries="$openssl_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            openssl_maccatalyst_binaries="$openssl_maccatalyst_binaries $lib"
        fi
    done
        
    iphoneos_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_iphoneos_binaries" "$openssl_headers" "iphoneos" "openssl")"
    mv "$iphoneos_openssl_framework" "build_iphoneos/"
        
    iphonesimulator_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_iphonesimulator_binaries" "$openssl_headers" "iphonesimulator" "openssl")"
    mv "$iphonesimulator_openssl_framework" "build_iphonesimulator/"
    
    watchos_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_watchos_binaries" "$openssl_headers" "watchos" "openssl")"
    mv "$watchos_openssl_framework" "build_watchos/"
    
    watchsimulator_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_watchsimulator_binaries" "$openssl_headers" "watchsimulator" "openssl")"
    mv "$watchsimulator_openssl_framework" "build_watchsimulator/"
    
    appletvos_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_appletvos_binaries" "$openssl_headers" "appletvos" "openssl")"
    mv "$appletvos_openssl_framework" "build_appletvos/"
    
    appletvsimulator_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_appletvsimulator_binaries" "$openssl_headers" "appletvsimulator" "openssl")"
    mv "$appletvsimulator_openssl_framework" "build_appletvsimulator/"
        
    maccatalyst_openssl_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$openssl_maccatalyst_binaries" "$openssl_headers" "macosx" "openssl")"
    mv "$maccatalyst_openssl_framework" "build_maccatalyst/"
    
    xcodebuild -create-xcframework \
        -framework "build_iphoneos/openssl.framework" \
        -framework "build_iphonesimulator/openssl.framework" \
        -framework "build_watchos/openssl.framework" \
        -framework "build_watchsimulator/openssl.framework" \
        -framework "build_appletvos/openssl.framework" \
        -framework "build_appletvsimulator/openssl.framework" \
        -framework "build_maccatalyst/openssl.framework" \
        -output "$ROOT/openssl.xcframework"
    
    ## ffi ##
    
    libffi_libs="$(all_platforms "libffi" "lib/libffi.a")"
    libffi_headers="$(all_platforms "libffi" "include")"
    
    libffi_iphoneos_binaries=""
    libffi_iphonesimulator_binaries=""
    libffi_watchos_binaries=""
    libffi_watchsimulator_binaries=""
    libffi_appletvos_binaries=""
    libffi_appletvsimulator_binaries=""
    libffi_maccatalyst_binaries=""
    
    for lib in $libffi_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            libffi_iphoneos_binaries="$libffi_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            libffi_iphonesimulator_binaries="$libffi_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            libffi_watchos_binaries="$libffi_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            libffi_watchsimulator_binaries="$libffi_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            libffi_appletvos_binaries="$libffi_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            libffi_appletvsimulator_binaries="$libffi_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            libffi_maccatalyst_binaries="$libffi_maccatalyst_binaries $lib"
        fi
    done
    
    iphoneos_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_iphoneos_binaries" "$libffi_headers" "iphoneos" "ffi")"
    mv "$iphoneos_libffi_framework" "build_iphoneos/"
    
    iphonesimulator_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_iphonesimulator_binaries" "$libffi_headers" "iphonesimulator" "ffi")"
    mv "$iphonesimulator_libffi_framework" "build_iphonesimulator/"
    
    watchos_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_watchos_binaries" "$libffi_headers" "watchos" "ffi")"
    mv "$watchos_libffi_framework" "build_watchos/"
    
    watchsimulator_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_watchsimulator_binaries" "$libffi_headers" "watchsimulator" "ffi")"
    mv "$watchsimulator_libffi_framework" "build_watchsimulator/"
    
    appletvos_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_appletvos_binaries" "$libffi_headers" "appletvos" "ffi")"
    mv "$appletvos_libffi_framework" "build_appletvos/"
    
    appletvsimulator_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_appletvsimulator_binaries" "$libffi_headers" "appletvsimulator" "ffi")"
    mv "$appletvsimulator_libffi_framework" "build_appletvsimulator/"
    
    maccatalyst_libffi_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$libffi_maccatalyst_binaries" "$libffi_headers" "macosx" "ffi")"
    mv "$maccatalyst_libffi_framework" "build_maccatalyst/"

    xcodebuild -create-xcframework \
            -framework "build_iphoneos/ffi.framework" \
            -framework "build_iphonesimulator/ffi.framework" \
            -framework "build_watchos/ffi.framework" \
            -framework "build_watchsimulator/ffi.framework" \
            -framework "build_appletvos/ffi.framework" \
            -framework "build_appletvsimulator/ffi.framework" \
            -framework "build_maccatalyst/ffi.framework" \
            -output "$ROOT/ffi.xcframework"

    ## lzma ##
    
    lzma_libs="$(all_platforms "xz" "lib/liblzma.a")"
    lzma_headers="$(all_platforms "xz" "include")"
    
    lzma_iphoneos_binaries=""
    lzma_iphonesimulator_binaries=""
    lzma_watchos_binaries=""
    lzma_watchsimulator_binaries=""
    lzma_appletvos_binaries=""
    lzma_appletvsimulator_binaries=""
    lzma_maccatalyst_binaries=""
    
    for lib in $lzma_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            lzma_iphoneos_binaries="$lzma_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            lzma_iphonesimulator_binaries="$lzma_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            lzma_watchos_binaries="$lzma_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            lzma_watchsimulator_binaries="$lzma_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            lzma_appletvos_binaries="$lzma_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            lzma_appletvsimulator_binaries="$lzma_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            lzma_maccatalyst_binaries="$lzma_maccatalyst_binaries $lib"
        fi
    done
    
    iphoneos_lzma_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_iphoneos_binaries" "$lzma_headers" "iphoneos" "lzma")"
    mv "$iphoneos_lzma_framework" "build_iphoneos/"
    
    iphonesimulator_lzma_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_iphonesimulator_binaries" "$lzma_headers" "iphonesimulator" "lzma")"
    mv "$iphonesimulator_lzma_framework" "build_iphonesimulator/"
    
    watchos_lzma_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_watchos_binaries" "$lzma_headers" "watchos" "lzma")"
    mv "$watchos_lzma_framework" "build_watchos/"
    
    watchsimulator_lzma_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_watchsimulator_binaries" "$lzma_headers" "watchsimulator" "lzma")"
    mv "$watchsimulator_lzma_framework" "build_watchsimulator/"
    
    appletvos_lzma_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_appletvos_binaries" "$lzma_headers" "appletvos" "lzma")"
    mv "$appletvos_lzma_framework" "build_appletvos/"
    
    appletvsimulator_lzma_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_appletvsimulator_binaries" "$lzma_headers" "appletvsimulator" "lzma")"
    mv "$appletvsimulator_lzma_framework" "build_appletvsimulator/"
    
    lzma_maccatalyst_binaries="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$lzma_maccatalyst_binaries" "$lzma_headers" "macosx" "lzma")"
    mv "$lzma_maccatalyst_binaries" "build_maccatalyst/"

    xcodebuild -create-xcframework \
            -framework "build_iphoneos/lzma.framework" \
            -framework "build_iphonesimulator/lzma.framework" \
            -framework "build_watchos/lzma.framework" \
            -framework "build_watchsimulator/lzma.framework" \
            -framework "build_appletvos/lzma.framework" \
            -framework "build_appletvsimulator/lzma.framework" \
            -framework "build_maccatalyst/lzma.framework" \
            -output "$ROOT/lzma.xcframework"

    ## bzip2 ##
    
    bz2_libs="$(all_platforms "bzip2" "lib/libbz2.a")"
    bz2_headers="$(all_platforms "bzip2" "include")"
    
    bz2_iphoneos_binaries=""
    bz2_iphonesimulator_binaries=""
    bz2_watchos_binaries=""
    bz2_watchsimulator_binaries=""
    bz2_appletvos_binaries=""
    bz2_appletvsimulator_binaries=""
    bz2_maccatalyst_binaries=""
    
    for lib in $bz2_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            bz2_iphoneos_binaries="$bz2_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            bz2_iphonesimulator_binaries="$bz2_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            bz2_watchos_binaries="$bz2_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            bz2_watchsimulator_binaries="$bz2_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            bz2_appletvos_binaries="$bz2_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            bz2_appletvsimulator_binaries="$bz2_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            bz2_maccatalyst_binaries="$bz2_maccatalyst_binaries $lib"
        fi
    done
    
    iphoneos_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_iphoneos_binaries" "$bz2_headers" "iphoneos" "bz2")"
    mv "$iphoneos_bz2_framework" "build_iphoneos/"
    
    iphonesimulator_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_iphonesimulator_binaries" "$bz2_headers" "iphonesimulator" "bz2")"
    mv "$iphonesimulator_bz2_framework" "build_iphonesimulator/"
    
    watchos_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_watchos_binaries" "$bz2_headers" "watchos" "bz2")"
    mv "$watchos_bz2_framework" "build_watchos/"
    
    watchsimulator_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_watchsimulator_binaries" "$bz2_headers" "watchsimulator" "bz2")"
    mv "$watchsimulator_bz2_framework" "build_watchsimulator/"
    
    appletvos_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_appletvos_binaries" "$bz2_headers" "appletvos" "bz2")"
    mv "$appletvos_bz2_framework" "build_appletvos/"
    
    appletvsimulator_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_appletvsimulator_binaries" "$bz2_headers" "appletvsimulator" "bz2")"
    mv "$appletvsimulator_bz2_framework" "build_appletvsimulator/"
    
    maccatalyst_bz2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$bz2_maccatalyst_binaries" "$bz2_headers" "macosx" "bz2")"
    mv "$maccatalyst_bz2_framework" "build_maccatalyst/"

    xcodebuild -create-xcframework \
            -framework "build_iphoneos/bz2.framework" \
            -framework "build_iphonesimulator/bz2.framework" \
            -framework "build_watchos/bz2.framework" \
            -framework "build_watchsimulator/bz2.framework" \
            -framework "build_appletvos/bz2.framework" \
            -framework "build_appletvsimulator/bz2.framework" \
            -framework "build_maccatalyst/bz2.framework" \
            -output "$ROOT/bz2.xcframework"

    ## mpdecimal ##
    
    mpdecimal_libs="$(all_platforms "mpdecimal" "lib/libmpdec.a") $(all_platforms "mpdecimal" "lib/libmpdec++.a")"
    mpdecimal_headers="$(all_platforms "mpdecimal" "include")"

    mpdecimal_iphoneos_binaries=""
    mpdecimal_iphonesimulator_binaries=""
    mpdecimal_watchos_binaries=""
    mpdecimal_watchsimulator_binaries=""
    mpdecimal_appletvos_binaries=""
    mpdecimal_appletvsimulator_binaries=""
    mpdecimal_maccatalyst_binaries=""
    
    for lib in $mpdecimal_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            mpdecimal_iphoneos_binaries="$mpdecimal_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            mpdecimal_iphonesimulator_binaries="$mpdecimal_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            mpdecimal_watchos_binaries="$mpdecimal_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            mpdecimal_watchsimulator_binaries="$mpdecimal_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            mpdecimal_appletvos_binaries="$mpdecimal_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            mpdecimal_appletvsimulator_binaries="$mpdecimal_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            mpdecimal_maccatalyst_binaries="$mpdecimal_maccatalyst_binaries $lib"
        fi
    done
    
    iphoneos_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_iphoneos_binaries" "$mpdecimal_headers" "iphoneos" "mpdec")"
    mv "$iphoneos_mpdecimal_framework" "build_iphoneos/"
    
    iphonesimulator_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_iphonesimulator_binaries" "$mpdecimal_headers" "iphonesimulator" "mpdec")"
    mv "$iphonesimulator_mpdecimal_framework" "build_iphonesimulator/"
    
    watchos_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_watchos_binaries" "$mpdecimal_headers" "watchos" "mpdec")"
    mv "$watchos_mpdecimal_framework" "build_watchos/"
    
    watchsimulator_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_watchsimulator_binaries" "$mpdecimal_headers" "watchsimulator" "mpdec")"
    mv "$watchsimulator_mpdecimal_framework" "build_watchsimulator/"
    
    appletvos_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_appletvos_binaries" "$mpdecimal_headers" "appletvos" "mpdec")"
    mv "$appletvos_mpdecimal_framework" "build_appletvos/"
    
    appletvsimulator_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_appletvsimulator_binaries" "$mpdecimal_headers" "appletvsimulator" "mpdec")"
    mv "$appletvsimulator_mpdecimal_framework" "build_appletvsimulator/"
    
    maccatalyst_mpdecimal_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$mpdecimal_maccatalyst_binaries" "$mpdecimal_headers" "macosx" "mpdec")"
    mv "$maccatalyst_mpdecimal_framework" "build_maccatalyst/"

    xcodebuild -create-xcframework \
            -framework "build_iphoneos/mpdec.framework" \
            -framework "build_iphonesimulator/mpdec.framework" \
            -framework "build_watchos/mpdec.framework" \
            -framework "build_watchsimulator/mpdec.framework" \
            -framework "build_appletvos/mpdec.framework" \
            -framework "build_appletvsimulator/mpdec.framework" \
            -framework "build_maccatalyst/mpdec.framework" \
            -output "$ROOT/mpdec.xcframework"

    ## ssh2 ##
    
    ssh2_libs="$(all_platforms "libssh2" "src/libssh2.a")"
    ssh2_headers="$(all_platforms "libssh2" "include")"
    
    ssh2_iphoneos_binaries=""
    ssh2_iphonesimulator_binaries=""
    ssh2_watchos_binaries=""
    ssh2_watchsimulator_binaries=""
    ssh2_appletvos_binaries=""
    ssh2_appletvsimulator_binaries=""
    ssh2_maccatalyst_binaries=""
    
    for lib in $ssh2_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            ssh2_iphoneos_binaries="$ssh2_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            ssh2_iphonesimulator_binaries="$ssh2_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            ssh2_watchos_binaries="$ssh2_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            ssh2_watchsimulator_binaries="$ssh2_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            ssh2_appletvos_binaries="$ssh2_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            ssh2_appletvsimulator_binaries="$ssh2_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            ssh2_maccatalyst_binaries="$ssh2_maccatalyst_binaries $lib"
        fi
    done
    
    iphoneos_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_iphoneos_binaries" "$ssh2_headers" "iphoneos" ssh2)"
    mv "$iphoneos_ssh2_framework" "build_iphoneos/"
    
    iphonesimulator_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_iphonesimulator_binaries" "$ssh2_headers" "iphonesimulator" ssh2)"
    mv "$iphonesimulator_ssh2_framework" "build_iphonesimulator/"
    
    watchos_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_watchos_binaries" "$ssh2_headers" "watchos" ssh2)"
    mv "$watchos_ssh2_framework" "build_watchos/"
    
    watchsimulator_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_watchsimulator_binaries" "$ssh2_headers" "watchsimulator" ssh2)"
    mv "$watchsimulator_ssh2_framework" "build_watchsimulator/"
    
    appletvos_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_appletvos_binaries" "$ssh2_headers" "appletvos" ssh2)"
    mv "$appletvos_ssh2_framework" "build_appletvos/"
    
    appletvsimulator_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_appletvsimulator_binaries" "$ssh2_headers" "appletvsimulator" ssh2)"
    mv "$appletvsimulator_ssh2_framework" "build_appletvsimulator/"
    
    maccatalyst_ssh2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$ssh2_maccatalyst_binaries" "$ssh2_headers" "macosx" ssh2)"
    mv "$maccatalyst_ssh2_framework" "build_maccatalyst/"

    xcodebuild -create-xcframework \
            -framework "build_iphoneos/ssh2.framework" \
            -framework "build_iphonesimulator/ssh2.framework" \
            -framework "build_watchos/ssh2.framework" \
            -framework "build_watchsimulator/ssh2.framework" \
            -framework "build_appletvos/ssh2.framework" \
            -framework "build_appletvsimulator/ssh2.framework" \
            -framework "build_maccatalyst/ssh2.framework" \
            -output "$ROOT/ssh2.xcframework"

    ## git2 ##
    
    git2_libs="$(all_platforms "libgit2" "libgit2.a")"
    git2_headers="$(all_platforms "libgit2" "include")"
    
    git2_iphoneos_binaries=""
    git2_iphonesimulator_binaries=""
    git2_watchos_binaries=""
    git2_watchsimulator_binaries=""
    git2_appletvos_binaries=""
    git2_appletvsimulator_binaries=""
    git2_maccatalyst_binaries=""
    
    for lib in $git2_libs; do
        if [[ "$lib" =~ "iphoneos" ]]; then
            git2_iphoneos_binaries="$git2_iphoneos_binaries $lib"
        elif [[ "$lib" =~ "iphonesimulator" ]]; then
            git2_iphonesimulator_binaries="$git2_iphonesimulator_binaries $lib"
        elif [[ "$lib" =~ "watchos" ]]; then
            git2_watchos_binaries="$git2_watchos_binaries $lib"
        elif [[ "$lib" =~ "watchsimulator" ]]; then
            git2_watchsimulator_binaries="$git2_watchsimulator_binaries $lib"
        elif [[ "$lib" =~ "appletvos" ]]; then
            git2_appletvos_binaries="$git2_appletvos_binaries $lib"
        elif [[ "$lib" =~ "appletvsimulator" ]]; then
            git2_appletvsimulator_binaries="$git2_appletvsimulator_binaries $lib"
        elif [[ "$lib" =~ "maccatalyst" ]]; then
            git2_maccatalyst_binaries="$git2_maccatalyst_binaries $lib"
        fi
    done
    
    iphoneos_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_iphoneos_binaries" "$git2_headers" "iphoneos" git2)"
    mv "$iphoneos_git2_framework" "build_iphoneos/"
    
    iphonesimulator_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_iphonesimulator_binaries" "$git2_headers" "iphonesimulator" git2)"
    mv "$iphonesimulator_git2_framework" "build_iphonesimulator/"
    
    watchos_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_watchos_binaries" "$git2_headers" "watchos" git2)"
    mv "$watchos_git2_framework" "build_watchos/"
    
    watchsimulator_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_watchsimulator_binaries" "$git2_headers" "watchsimulator" git2)"
    mv "$watchsimulator_git2_framework" "build_watchsimulator/"
    
    appletvos_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_appletvos_binaries" "$git2_headers" "appletvos" git2)"
    mv "$appletvos_git2_framework" "build_appletvos/"
    
    appletvsimulator_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_appletvsimulator_binaries" "$git2_headers" "appletvsimulator" git2)"
    mv "$appletvsimulator_git2_framework" "build_appletvsimulator/"
    
    maccatalyst_git2_framework="$(CREATE_FAT_DYNAMIC_LIBRARIES_FROM_STATIC_ARCHIVES "$git2_maccatalyst_binaries" "$git2_headers" "macosx" git2)"
    mv "$maccatalyst_git2_framework" "build_maccatalyst/"
    
    # Merge frameworks
            
    xcodebuild -create-xcframework \
            -framework "build_iphoneos/git2.framework" \
            -framework "build_iphonesimulator/git2.framework" \
            -framework "build_watchos/git2.framework" \
            -framework "build_watchsimulator/git2.framework" \
            -framework "build_appletvos/git2.framework" \
            -framework "build_appletvsimulator/git2.framework" \
            -framework "build_maccatalyst/git2.framework" \
            -output "$ROOT/git2.xcframework"
    
    rm -rf "build_iphoneos" "build_iphonesimulator" "build_watchos" "build_watchsimulator" "build_appletvos" "build_appletvsimulator" "build_maccatalyst"
        
    # Standard Library

    rm -rf "$ROOT"/*-cp$PLAIN_VERSION* &> /dev/null
    rm -rf "$ROOT/Python$PLAIN_VERSION.xcframework" &> /dev/null

    pushd "Dependencies"
    packaged_frameworks=()
    find "cpython/build" -name "*.framework" -print0 | while read -d $'\0' framework
    do
        found="no"
        for packaged_framework in "${packaged_frameworks[@]}"; do
            if [[ "$packaged_framework" == "$(basename $framework)" ]]; then
                found="yes"
                break
            fi
        done
        
        if [[ "$found" = "yes" ]]; then
            continue
        fi
        
        PACKAGE_FRAMEWORKS "$(all_platforms "cpython" "lib/$(basename $framework)")"
        packaged_frameworks=("${packaged_frameworks[@]}" "$(basename $framework)")
    done
    popd
    
    # _extensionsimporter
    
    pushd "$ROOT/Sources/_extensionsimporter"
    ./build.sh "$VERSION"
    popd
fi

# Other Extensions

pushd ..

libs=""
for plat in build/*; do
    for lib in $plat/*; do
        libs="$libs $lib"
    done
    break
done

for lib in $libs; do
    if [ "$(basename $lib)" = "$BUILD_LIBRARY" ]; then
        for framework in $lib/*.framework; do
            PACKAGE_FRAMEWORKS "$(all_platforms "." "$(basename "$lib")/$(basename "$framework")")"
        done
        break
    fi
done
popd