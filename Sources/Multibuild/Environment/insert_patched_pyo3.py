#!/usr/bin/env build_python

import sys

# Replace pyo3 in Cargo.toml with fork
new_config = ""
for line in sys.stdin.readlines():
    if line.startswith("pyo3 = "):
        line = 'pyo3 = { git = "https://gatites.no.binarios.cl/git/pyto/pyo3.git"'
        if 'features = ["abi3"]' in line:
            line += ', features = ["abi3"]'
        line += " }\n"
    elif line.startswith("pyo3-build-config = "):
        line = 'pyo3-build-config = { git = "https://gatites.no.binarios.cl/git/pyto/pyo3.git" }\n'
    new_config += line

print(new_config)