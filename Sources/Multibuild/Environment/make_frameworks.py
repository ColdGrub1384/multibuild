import sys
import os
import shutil
import shlex
from pathlib import Path
from subprocess import Popen, PIPE

# First argument: Python version
# Second argument: the name of the submodule, e.g: numpy
# Third argument: the name of the directory containing the frameworks, e.g: Numpy
# Optional: --absolute-path: treats the third positional argument as a full path that can be relative but not to the default installation directory

tools_dir = os.path.dirname(os.path.abspath(__file__))
insert_dylib = os.path.join(tools_dir, "../../..", "insert_dylib/build/bin", "insert_dylib")

# https://gist.github.com/willprice/311faace6fb4f514376fa405d2220615
def relative_symlink(target, destination):
    """Create a symlink pointing to ``target`` from ``location``.
    Args:
        target: The target of the symlink (the file/directory that is pointed to)
        destination: The location of the symlink itself.
    """
    target = Path(target)
    destination = Path(destination)
    target_dir = destination.parent
    target_dir.mkdir(exist_ok=True, parents=True)
    relative_source = os.path.relpath(target, target_dir)
    dir_fd = os.open(str(target_dir.absolute()), os.O_RDONLY)
    try:
        os.symlink(relative_source, destination.name, dir_fd=dir_fd)
    finally:
        os.close(dir_fd)

def list_extensions(dir):
    files = list()
    for item in os.listdir(dir):
        abspath = os.path.join(dir, item)
        try:
            if os.path.isdir(abspath):
                files = files + list_extensions(abspath)
            elif abspath.endswith(".so"):
                files.append(abspath)
        except FileNotFoundError as err:
            print('invalid directory\n', 'Error: ', err)
    return files

info = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>{"{}"}</string>
    <key>CFBundleIdentifier</key>
    <string>ch.ada.Pyto.{"{}"}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>{"{}"}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>{os.environ["MINIMUM_OS_VERSION"]}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>{os.environ["INFO_PLATFORM_NAME"]}</string>
    </array>
</dict>
</plist>"""

top_level = False
absolute_path = False
argv = []
for arg in sys.argv:
    if arg == "--top-level":
        top_level = True
    elif arg == "--absolute-path":
        absolute_path = True
    else:
        argv.append(arg)
sys.argv = argv

try:
    os.chdir(os.path.dirname(__file__)+"/../"+sys.argv[2]+"/build")
except FileNotFoundError:
    pass

for dir in os.listdir("."):
    if dir.startswith("lib."+os.environ["S"]):
        os.chdir(dir)
        break

extensions = list_extensions(".")

if absolute_path:
    frameworks_path = argv[3]
else:
    frameworks_path = f"../../../../build/{os.environ['PLATFORM']}.{os.environ['ARCHITECTURE']}/"+argv[3]

if not os.path.isdir(frameworks_path):
    os.makedirs(frameworks_path)

for file in os.listdir(frameworks_path):
    if file.endswith(".framework") and not file.split(".")[0] in sys.argv:
        shutil.rmtree(os.path.join(frameworks_path, file))

def remove(framework_path):
    if os.path.isdir(framework_path):
        shutil.rmtree(framework_path)

for extension in extensions:
    parts = extension.split("/")
    try:
        pyversion = "cp"+parts[-1].split(".")[1].split("-")[1]
    except IndexError:
        pyversion = "abi3"
    del parts[0]
    name = parts[-1].split(".")[0]
    del parts[-1]
    parts.append(name)
    parts.append(pyversion)
    if "abi3" not in extension.split("/")[-1] and pyversion != "cp"+sys.argv[1].replace(".", ""):
        continue
    if top_level:
        del parts[0]
    framework_name = "-".join(parts)+".framework"
    framework_path = os.path.join(frameworks_path, framework_name)
 
    remove(framework_path)
 
    os.makedirs(framework_path)

    name = os.path.basename(extension.split("/")[-1].split(".")[0])

    f = open(os.path.join(framework_path, "Info.plist"), "w+")
    f.write(info.format(extension.split("/")[-1], "".join(parts).replace("_", ""), name))
    f.close()
    
    python_fwork_name = "Python"+sys.argv[1].replace(".", "")
    python_fwork = f"@rpath/{python_fwork_name}.framework/{python_fwork_name}"
    print(framework_path)
    shutil.copy(extension, framework_path)
    
    otool_p = Popen(["otool", "-l", os.path.join(framework_path, extension)], stdout=PIPE)
    otool_p.wait()
    otool_o = otool_p.stdout.read().decode("utf-8")
    if f"name {python_fwork}" not in otool_o:
        os.system(shlex.join([insert_dylib, python_fwork, "--inplace", "--all-yes", os.path.join(framework_path, extension)]))
    os.system(shlex.join(["codesign", "--remove-signature", os.path.join(framework_path, extension)]))
    
    if "MAC_CATALYST" in os.environ:
        current = os.path.join(framework_path, "Versions", "A")
        resources = os.path.join(current, "Resources")
        os.makedirs(resources)
        shutil.move(os.path.join(framework_path, "Info.plist"), resources)
        shutil.move(os.path.join(framework_path, extension), current)
        relative_symlink(current, os.path.join(framework_path, "Versions", "Current"))
        relative_symlink(os.path.join(framework_path, "Versions", "Current", extension), os.path.join(framework_path, extension))
        relative_symlink(os.path.join(framework_path, "Versions", "Current", "Resources"), os.path.join(framework_path, "Resources"))
