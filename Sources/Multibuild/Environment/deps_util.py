#!/usr/bin/python3

import sys
import os
import shutil
from subprocess import Popen, PIPE

try:
    site = os.path.abspath(sys.argv[1])
except IndexError as e:
    print("Provide the path of the site-packages directory to inspect as the first argument.", file=sys.stderr)
    raise e

try:
    python = os.path.abspath(sys.argv[2])
except IndexError as e:
    print("Provide the path of python as the second argument.", file=sys.stderr)
    raise e

Popen([python, "-m", "venv", site]).wait()
python = os.path.join(site, "bin", python.split("/")[-1])

argv = []
for argument in sys.argv:
    if argument.endswith("/requires.txt"):
        with open(argument, "r") as f:
            req = ""
            for line in f.read().split("\n"):
                if line.startswith("["):
                    break
                else:
                    req += line+"\n"
            tmp_file = "/tmp/pip_requires.txt"
            with open(tmp_file, "w+") as f:
                f.write(req)
            argv.append(tmp_file)
    elif argument.endswith("/METADATA"):
        with open(argument, "r") as f:
            req = ""
            for line in f.read().split("\n"):
                if line.startswith("Requires-Dist:"):
                    dep = line.replace("Requires-Dist:", "")
                    if dep.startswith(" "):
                        dep = dep[1:]
                    if len(dep.split(";")) > 1:
                        continue
                    req += dep+"\n"
            tmp_file = "/tmp/pip_requires.txt"
            with open(tmp_file, "w+") as f:
                f.write(req)
            argv.append(tmp_file)
    else:
        argv.append(argument)


if len(sys.argv) > 3:
    os.putenv("PYTHONPATH", site)
    p = Popen([python, "-m", "pip"]+argv[3:])
    p.wait()

    new_site = os.path.join(site, "lib", python.split("/")[-1])
    bin_dir = os.path.join(site, "bin")
    if os.listdir(new_site) == ["site-packages"]:
        new_site = os.path.join(new_site, "site-packages")
    for pkg in os.listdir(new_site):
        path = os.path.join(new_site, pkg)
        new_path = os.path.join(site, pkg)
        if os.path.isdir(new_path):
            shutil.rmtree(new_path)
        elif os.path.isfile(new_path):
            os.remove(new_path)
        shutil.move(path, new_path)
    
    shutil.rmtree(os.path.join(site, "lib"))
    shutil.rmtree(os.path.join(site, "include"))
    os.remove(os.path.join(site, "pyvenv.cfg"))
    for file in os.listdir(bin_dir):
        path = os.path.join(bin_dir, file)
        if file.lower().startswith("activate") or file.startswith("python"):
            os.remove(path)
