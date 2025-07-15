def activate_venv(home):
    import sysconfig
    import site
    import sys
    import os
    
    try:
        from pip._internal.locations import base
    except ModuleNotFoundError:
        base = None

    include_system_site_packages = False
    python_version = tuple(sys.version_info)[:3]
    version = python_version
    bin_path = home
    proj_path = os.path.join(bin_path, "..")
    pyvenv = os.path.join(proj_path, "pyvenv.cfg")
    if os.path.exists(pyvenv):
        with open(pyvenv, "r") as f:
            for line in f.read().split("\n"):
                try:
                    key, value = tuple(line.split("="))
                except ValueError:
                    continue
                key = key.replace(" ", "")
                if value.startswith(" "):
                    value = value[1:]
                
                if key == "include-system-site-packages":
                    include_system_site_packages = (value == "true")
                elif key == "version":
                    major = None
                    minor = None
                    micro = 0
                    for comp in value.split("."):
                        if major is None:
                            major = int(comp)
                        elif minor is None:
                            minor = int(comp)
                        elif micro == 0:
                            micro = int(comp)
                    version = (major, minor, micro)

    proj_path = os.path.abspath(os.path.join(bin_path, ".."))
    site_path = os.path.join(proj_path, "lib", f"python{version[0]}.{version[1]}", "site-packages")

    if python_version != version:
        msg = "pyvenv.cfg version value is different than Pyto's embedded Python version. Using different versions is not supported."
        raise SystemError(msg)

    if "PYTHONPATH" in sys.path:
        path = os.getenv(f"PYTHONPATH").split(":")
    else:
        path = sys.path
    path.insert(0, site_path)
    if include_system_site_packages:
        path.append(site.USER_SITE)
    else:
        for site_path in site.getsitepackages():
            if site_path in path:
                path.remove(site_path)

    if base is not None:
        base.user_site = site_path
        base.site_packages = site_path
    site.USER_SITE = site_path
    sys.path = path
    sys.prefix = proj_path
    sys.exec_prefix = proj_path
    sysconfig._PREFIX = sys.prefix
    sysconfig._EXEC_PREFIX = sys.exec_prefix
    sysconfig._INSTALL_SCHEMES["posix_prefix"]["platlib"] = site_path
    sysconfig._INSTALL_SCHEMES["posix_prefix"]["purelib"] = site_path
    sysconfig._INSTALL_SCHEMES["posix_prefix"]["scripts"] = bin_path
    sysconfig._INSTALL_SCHEMES["posix_prefix"]["include"] = os.path.join(proj_path, "include")
    sysconfig._INSTALL_SCHEMES["posix_prefix"]["data"] = proj_path
