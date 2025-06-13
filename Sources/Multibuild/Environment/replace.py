#!/usr/bin/python3

import sys

file_path = sys.argv[1]
find = sys.argv[2].replace("\\n", "\n")
replace = sys.argv[3].replace("\\n", "\n")

with open(file_path, "r") as r:
    text = r.read()
    text = text.replace(find, replace)
    with open(file_path, "w") as w:
        w.write(text)
