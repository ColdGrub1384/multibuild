#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

find .. -name "*.egg-info" -print0 | while read -d $'\0' file
do
    DIST_INFO="$(basename $file .egg-info)"
    cp -rf "$file" "$SITE_DIR"
    rm -rf "$SITE_DIR/$DIST_INFO"*.dist-info
done
