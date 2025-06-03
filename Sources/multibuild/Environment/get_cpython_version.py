#!/usr/bin/python3

f = open("README.rst", "r")
content = f.read()
f.close()

prefix = "This is Python version "
first_line = content.split("\n")[0]
version = first_line.split(prefix)[1].split(" ")[0]

print(version)

