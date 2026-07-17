#!/usr/bin/env build_python

import sys
import re

lines = sys.stdin.readlines()

# First pass: find [dependencies] and [dependencies.pyo3], extract pyo3 info
dependencies_idx = None
pyo3_section_start = None
pyo3_section_end = None
pyo3_features = None

for i, line in enumerate(lines):
    if line.strip() == "[dependencies]":
        dependencies_idx = i
    elif line.strip() == "[dependencies.pyo3]":
        pyo3_section_start = i
        # Find where this section ends
        for j in range(i + 1, len(lines)):
            if lines[j].strip().startswith("[") or j == len(lines) - 1:
                pyo3_section_end = j if lines[j].strip().startswith("[") else j + 1
                break
        # Extract features
        for j in range(i + 1, pyo3_section_end):
            features_match = re.search(r'features\s*=\s*(\[.*?\])', lines[j])
            if features_match:
                pyo3_features = features_match.group(1)
                break

# Build the pyo3 entry
pyo3_entry = None
if pyo3_section_start is not None:
    pyo3_entry = 'pyo3 = { git = "https://git.gatit.es/pyto/pyo3.git", branch = "main"'
    if pyo3_features:
        pyo3_entry += f', features = {pyo3_features}'
    pyo3_entry += ' }'

# Second pass: rebuild file
new_config = ""
i = 0
pyo3_added = False

while i < len(lines):
    # Skip [dependencies.pyo3] section
    if i == pyo3_section_start:
        i = pyo3_section_end
        continue
    
    line = lines[i]
    
    # Add pyo3 to existing [dependencies]
    if i == dependencies_idx and pyo3_entry and not pyo3_added:
        new_config += line
        # Look ahead to find first non-empty line
        j = i + 1
        while j < len(lines) and lines[j].strip() == "":
            j += 1
        # Add pyo3 entry before the next content line or at end
        new_config += pyo3_entry + '\n'
        pyo3_added = True
        i += 1
        continue
    
    # Handle inline pyo3 references
    strip_line = line.strip()
    if strip_line.startswith("pyo3 ="):
        indent = line[:line.find("pyo3")]
        features_match = re.search(r'features\s*=\s*(\[.*?\])', line)
        line = indent + 'pyo3 = { git = "https://git.gatit.es/pyto/pyo3.git", branch = "main"'
        if features_match:
            line += f', features = {features_match.group(1)}'
        elif 'features = ["abi3"]' in line:
            line += ', features = ["abi3"]'
        line += " }\n"
        pyo3_added = True
    elif strip_line.startswith("pyo3-build-config ="):
        indent = line[:line.find("pyo3-build-config")]
        line = indent + 'pyo3-build-config = { git = "https://git.gatit.es/pyto/pyo3.git", branch = "main" }\n'
    
    new_config += line
    i += 1

# If not found anywhere, append patch sections
if not pyo3_added and pyo3_entry is None:
    new_config += '\n[patch.crates-io]\npyo3 = { git = "https://git.gatit.es/pyto/pyo3.git", branch = "main" }\n'
    new_config += 'pyo3-build-config = { git = "https://git.gatit.es/pyto/pyo3.git", branch = "main" }\n'

print(new_config)