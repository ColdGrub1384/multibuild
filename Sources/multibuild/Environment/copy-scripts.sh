#!/bin/bash

for arg in "$@"
do
    path="$BUILD_DIR/$arg"
    new_path="$SITE_DIR/$arg"
    rm -rf "$new_path" 2>/dev/null
    cp -r "$path" "$new_path"
done
