#!/usr/bin/env build_python

"""
Python interpreter.

usage: python [-c cmd | -m mod | file] [arg]
"""

import sys
import os

if "SETUPTOOLS_USE_DISTUTILS" in os.environ:
    del os.environ["SETUPTOOLS_USE_DISTUTILS"]

import runpy
import shlex
import platform
import subprocess
import sysconfig
import platform
import traceback as tb
import setuptools
import distutils.sysconfig
from collections import namedtuple
from code import interact

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from _activate_venv import activate_venv

## Configure for cross compilation ##

def get_python_inc(plat_specific=False):
    return os.environ["PYTHON_HEADERS"]

def ios_ver():
    IOSVersion = namedtuple("IOS", ["system", "release", "model", "is_simulator"])
    is_simulator = ("-simulator" in sysconfig.get_config_var('SOABI'))
    match sys.platform:
        case "ios":
            if "macabi" in sysconfig.get_config_var('SOABI'):
                return IOSVersion("macOS", "11.0", "Mac", False)
            else:
                return IOSVersion("iOS", "13.0", "iPhone", is_simulator)
        case "watchos":
            return IOSVersion("watchOS", "6.0", "Apple Watch", is_simulator)
        case "tvos":
            return IOSVersion("watchOS", "6.0", "Apple Watch", is_simulator)

def platform_system():
    return os.environ["PYTHON_SYSTEM"]

if "PYTHON_CROSS_COMPILING" in os.environ:
    __file__ = os.environ["PYTHON_EXEC_PATH"]
    sys.platform = os.environ["PYTHON_PLATFORM"].split("_")[0]
    sys.implementation._multiarch = f"{os.environ["ARCHS"].replace(";", "-")}{os.environ["SDK_NAME"]}"
    platform.system = platform_system
    platform.ios_ver = ios_ver
    subprocess._can_fork_exec = True
    distutils.sysconfig.get_python_inc = get_python_inc
    sys.argv.pop(0)
    sys.executable = os.path.join(os.path.dirname(os.path.abspath(__file__)), "python3")
    sys._base_executable = sys.executable
    sys.argv.insert(0, sys.executable)

## Interpreter  ##

_usage = "usage: python [-c cmd | -m mod | file | -] [arg]"

def main():

    if len(sys.argv) > 1 and sys.argv[1] == "-u":
        sys.argv.pop(1)

    bin_path = os.path.abspath(os.path.dirname(__file__))
    pyvenv = os.path.join(os.path.dirname(bin_path), "pyvenv.cfg")
    if os.path.exists(pyvenv):
        activate_venv(bin_path)

    if len(sys.argv) == 1 and sys.stdin.isatty():
        return interact()
    elif len(sys.argv) == 1 and not sys.stdin.isatty():
        if len(sys.argv) > 1:
            sys.argv.pop(0)
        return exec(sys.stdin.read(), globals={})

    try:
        if sys.argv[1] == "--version":
            return print("Python "+sys.version.split(" ")[0])
    except IndexError:
        pass

    if sys.argv[1] == "-c":
        try:
            _code = sys.argv[2] # python -c "import sys; print(sys.argv)" foo bar
            sys.argv.pop(0) # -c "import sys; print(sys.argv)" foo bar
            sys.argv.pop(0) # "import sys; print(sys.argv)" foo bar
            sys.argv[0] = "-c" # -c foo bar
        except IndexError:
            print(_usage, file=sys.stderr)
            sys.exit(1)

        exec(_code)
    elif sys.argv[1] == "-m":
        try:
            sys.argv.pop(0)
            sys.argv.pop(0)

            for mod in list(sys.modules.keys()):
                if mod.startswith(sys.argv[0]):
                    del sys.modules[mod]
        except IndexError:
            print(_usage, file=sys.stderr)
            sys.exit(1)

        cwd = os.getcwd()
        if cwd not in sys.path:
            sys.path.insert(-1, cwd)
            added = True
        else:
            sys.path.remove(cwd)
            sys.path.insert(-1, cwd)
            added = False

        try:
            runpy.run_module(sys.argv[0], run_name="__main__")
        finally:
            if added and cwd in sys.path:
                sys.path.remove(cwd)

    elif sys.argv[1] == "-h" or sys.argv[1] == "--help":
        print(_usage, file=sys.stderr)
        sys.exit(1)
    else:
        sys.argv.pop(0)

        try:
            script = sys.argv[0]
            script_dir = os.path.abspath(os.path.dirname(script))
            sys.path.append(script_dir)
            runpy.run_path(script, run_name="__main__")
        except Exception as e:
            exc_type, exc, tb = sys.exc_info()
            sys.excepthook(exc_type, exc, tb)
            sys.exit(1)

if __name__ == "__main__":
    main()
