#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

find .. -name "*.dist-info" -print0 | while read -d $'\0' file
do
    EGG_INFO="$(basename $file .dist-info)"
    PARTS=(${EGG_INFO//-/ })
    EGG_INFO="${PARTS[0]}"
    cp -rf "$file" "$SITE_DIR"
    rm -rf "$SITE_DIR/$EGG_INFO"*.egg-info
done
